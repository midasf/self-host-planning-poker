import { Component, ChangeDetectionStrategy } from '@angular/core';
import { TranslocoDirective } from '@ngneat/transloco';

@Component({
    selector: 'shpp-footer',
    templateUrl: './footer.component.html',
    changeDetection: ChangeDetectionStrategy.Eager,
    imports: [TranslocoDirective]
})
export class FooterComponent {

}
