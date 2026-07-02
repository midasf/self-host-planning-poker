import { Component, ChangeDetectionStrategy } from '@angular/core';
import { TranslocoDirective } from '@ngneat/transloco';

@Component({
    selector: 'shpp-nav-app-title',
    templateUrl: './nav-app-title.component.html',
    changeDetection: ChangeDetectionStrategy.Eager,
    imports: [TranslocoDirective]
})
export class NavAppTitleComponent {

}
