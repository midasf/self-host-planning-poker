import { inject, Injectable } from '@angular/core';
import { environment } from '../../environments/environment';
import { BehaviorSubject, filter, map, Observable, Subject } from 'rxjs';
import { ErrorMessage, GameInfo, GameState } from '../model/events';
import { Deck, decksDict } from '../model/deck';
import { ActivatedRouteSnapshot, CanActivateFn, Router, RouterStateSnapshot, UrlTree } from '@angular/router';
import { HashMap, TranslocoService } from '@ngneat/transloco';
import { UserInformationService } from '../shared/user-info/user-information.service';
import { ToastService } from '../shared/toast/toast.service';

/** Frames received from the WebSocket API (see aws/src/broadcast.py). */
interface EventFrame {
  type: 'event';
  event: 'state' | 'info' | 'new_game';
  data: any;
}
interface AckFrame {
  type: 'ack';
  requestId: string;
  data?: any;
  error?: ErrorMessage;
}
type ServerFrame = EventFrame | AckFrame;

interface PendingAck {
  resolve: (data: any) => void;
  reject: (error: any) => void;
  timer: ReturnType<typeof setTimeout>;
}

@Injectable({
  providedIn: 'root'
})
export class CurrentGameService {
  private readonly totalAttempts = 10;
  private readonly reconnectDelaySeconds = 5;
  private readonly ackTimeoutMs = 10000;

  private ws?: WebSocket;
  private gameId?: string;
  private joined = false;
  private manualClose = false;
  private reconnectAttempts = 0;
  private initialJoinResolve?: (result: boolean | UrlTree) => void;
  private readonly pending = new Map<string, PendingAck>();

  private stateSubject = new BehaviorSubject<GameState>({});
  private infoSubject = new BehaviorSubject<GameInfo | null>(null);
  private newGameSubject = new Subject<void>();

  constructor(private router: Router,
              private userInformation: UserInformationService,
              private transloco: TranslocoService,
              private toastService: ToastService) {
    this.userInformation.nameObservable().subscribe((name: string) => {
      if (this.isConnected()) {
        this.emit('set_player_name', { name: name });
      }
    });
    this.userInformation.spectatorObservable().subscribe((spectator: boolean) => {
      if (this.isConnected()) {
        this.emit('set_spectator', { spectator: spectator });
      }
    });
  }

  public get state$(): Observable<GameState> {
    return this.stateSubject.asObservable();
  }

  public get gameInfo$(): Observable<GameInfo | null> {
    return this.infoSubject.asObservable();
  }

  public get newGame$(): Observable<void> {
    return this.newGameSubject.asObservable();
  }

  public get revealed$(): Observable<boolean> {
    return this.gameInfo$.pipe(
      map((info: GameInfo | null) => info !== null ? info.revealed : false)
    );
  }

  public get deck$(): Observable<Deck> {
    return this.infoSubject.asObservable()
    .pipe(
      filter((gameInfo: GameInfo | null): gameInfo is GameInfo => gameInfo !== null),
      map((gameInfo: GameInfo) => decksDict[gameInfo?.deck])
    );
  }

  canActivate(route: ActivatedRouteSnapshot): Promise<boolean | UrlTree> {
    this.gameId = route.params['gameId'];
    this.manualClose = false;
    this.reconnectAttempts = 0;
    return new Promise<boolean | UrlTree>((resolve) => {
      this.initialJoinResolve = resolve;
      this.connect();
    });
  }

  public leave(): void {
    this.manualClose = true;
    this.joined = false;
    this.ws?.close();
    this.ws = undefined;
    this.stateSubject.next({});
    this.infoSubject.next(null);
  }

  public renameGame(newName: string): void {
    this.emit('rename_game', { name: newName });
  }

  public setDeck(deck: Deck): void {
    this.emit('set_deck', { deck: deck.name });
  }

  public pickCard(cardValue: number | null): void {
    this.emit('pick_card', { card: cardValue });
  }

  public revealCards(): void {
    this.emit('reveal_cards');
  }

  public endTurn(): void {
    this.emit('end_turn');
  }

  // --- WebSocket lifecycle ---

  private isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  private connect(): void {
    this.ws = new WebSocket(environment.websocketUrl);
    this.ws.onopen = () => this.sendJoin();
    this.ws.onmessage = (event: MessageEvent) => this.onMessage(event);
    this.ws.onclose = (event: CloseEvent) => this.onClose(event);
  }

  private sendJoin(): void {
    const isReconnect = this.joined;
    const attempts = this.reconnectAttempts;
    this.request('join', {
      game: this.gameId,
      name: this.userInformation.getName(),
      spectator: this.userInformation.isSpectator(),
      playerId: this.userInformation.getPlayerId()
    }).then(
      (response: GameInfo) => {
        this.infoSubject.next(response);
        this.userInformation.setPlayerIdSubject(response.playerId);
        this.joined = true;
        this.reconnectAttempts = 0;
        if (this.initialJoinResolve) {
          this.initialJoinResolve(true);
          this.initialJoinResolve = undefined;
        } else if (isReconnect) {
          this.success('reconnect.success', { attempts: attempts });
        }
      },
      (reason: ErrorMessage | any) => {
        this.handleError(reason);
        if (this.initialJoinResolve) {
          this.manualClose = true;
          this.ws?.close();
          this.initialJoinResolve(this.router.parseUrl('/'));
          this.initialJoinResolve = undefined;
        }
      });
  }

  private onMessage(event: MessageEvent): void {
    let frame: ServerFrame;
    try {
      frame = JSON.parse(event.data);
    } catch {
      return;
    }
    if (frame.type === 'ack') {
      const pending = this.pending.get(frame.requestId);
      if (pending) {
        clearTimeout(pending.timer);
        this.pending.delete(frame.requestId);
        if (frame.error) {
          pending.reject(frame.error);
        } else {
          pending.resolve(frame.data);
        }
      }
    } else if (frame.type === 'event') {
      switch (frame.event) {
        case 'state':
          this.stateSubject.next(frame.data);
          break;
        case 'info':
          this.infoSubject.next(frame.data);
          break;
        case 'new_game':
          this.newGameSubject.next();
          break;
      }
    }
  }

  private onClose(event: CloseEvent): void {
    this.pending.forEach((pending) => {
      clearTimeout(pending.timer);
      pending.reject('disconnected');
    });
    this.pending.clear();

    if (this.manualClose) {
      return;
    }
    this.error('errors.disconnect', { reason: event.reason || 'connection lost', delay: this.reconnectDelaySeconds });
    this.scheduleReconnect();
  }

  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.totalAttempts) {
      this.error('reconnect.failed', { attempts: this.totalAttempts });
      return;
    }
    this.reconnectAttempts++;
    this.info('reconnect.attempt', { attempt: this.reconnectAttempts, total: this.totalAttempts });
    setTimeout(() => {
      if (!this.manualClose) {
        this.connect();
      }
    }, this.reconnectDelaySeconds * 1000);
  }

  // --- request/ack helpers ---

  /** Send an action and resolve/reject with the server's ack (matched by requestId). */
  private request(action: string, data?: any): Promise<any> {
    return new Promise((resolve, reject) => {
      if (!this.isConnected()) {
        reject('disconnected');
        return;
      }
      const requestId = crypto.randomUUID();
      const timer = setTimeout(() => {
        this.pending.delete(requestId);
        reject('ack timeout');
      }, this.ackTimeoutMs);
      this.pending.set(requestId, { resolve, reject, timer });
      this.ws!.send(JSON.stringify({ action, requestId, data: data ?? {} }));
    });
  }

  /** Fire an action, surfacing any error the server acks back (mirrors the old emit callbacks). */
  private emit(action: string, data?: any): void {
    this.request(action, data).catch((error) => this.handleError(error));
  }

  private handleError(error?: ErrorMessage | any): void {
    if (!!error) {
      if ('error' in error) {
        this.error(`errors.${error.code}`, { message: error.message });
      } else {
        this.error(`errors.0`, { message: error });
      }
    }
  }

  private info(key: string, translateParams?: HashMap): void {
    this.transloco.selectTranslate(key, translateParams).subscribe((text) => {
      console.info(text);
      this.toastService.show(text, { className: 'bg-info' });
    })
  }

  private success(key: string, translateParams?: HashMap): void {
    this.transloco.selectTranslate(key, translateParams).subscribe((text) => {
      console.info(text);
      this.toastService.show(text, { className: 'bg-success text-light' });
    });
  }

  private error(key: string, translateParams?: HashMap): void {
    this.transloco.selectTranslate(key, translateParams).subscribe((text) => {
      console.error(text);
      this.toastService.show(text, { className: 'bg-danger text-light' });
    })
  }

}

export const canActivateGame: CanActivateFn = (route: ActivatedRouteSnapshot, state: RouterStateSnapshot) => {
  return inject(CurrentGameService).canActivate(route);
}
