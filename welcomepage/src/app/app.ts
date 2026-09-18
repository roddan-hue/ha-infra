import { Component, inject, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { toSignal } from '@angular/core/rxjs-interop';
import { map } from 'rxjs';

@Component({
  imports: [RouterOutlet],
  selector: 'app-root',
  styleUrl: './app.css',
  templateUrl: './app.html',
})
export class App {
  protected readonly title = signal('welcomepage');

  // testing-only: identifies which EC2 instance/ASG member served this request
  private readonly http = inject(HttpClient);
  protected readonly instanceId = toSignal(
    this.http.get<{ instanceId: string }>('/api/instance').pipe(map((r) => r.instanceId)),
    { initialValue: 'loading...' },
  );
}
