import { Component, ChangeDetectionStrategy } from '@angular/core';
import { TranslocoDirective } from '@ngneat/transloco';
import { BaseHrefPipe } from "../shared/base-href.pipe";

@Component({
    selector: 'shpp-navigation-bar',
    templateUrl: './navigation-bar.component.html',
    imports: [TranslocoDirective, BaseHrefPipe],
    changeDetection: ChangeDetectionStrategy.Eager,
    styleUrls: ['./navigation-bar.component.scss']
})
export class NavigationBarComponent {

}
