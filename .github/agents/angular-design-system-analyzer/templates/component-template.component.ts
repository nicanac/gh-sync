import { Component, OnInit, Input, Output, EventEmitter } from '@angular/core';

/**
 * [Component Description]
 *
 * @example
 * <app-component-name [property]="value" (event)="handler($event)"></app-component-name>
 */
@Component({
  selector: 'app-component-name',
  templateUrl: './component-name.component.html',
  styleUrls: ['./component-name.component.scss'],
})
export class ComponentNameComponent implements OnInit {
  /**
   * Input property description
   */
  @Input() property: string = '';

  /**
   * Output event description
   */
  @Output() event = new EventEmitter<any>();

  constructor() {
    // Constructor logic
  }

  ngOnInit(): void {
    // Initialization logic
  }

  /**
   * Method description
   */
  public methodName(): void {
    // Method implementation
  }
}
