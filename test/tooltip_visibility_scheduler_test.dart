import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/src/tooltip_visibility_scheduler.dart';

void main() {
  group('TooltipVisibilityScheduler', () {
    test('child enter with no waitDuration shows immediately', () {
      var shows = 0;
      final scheduler = TooltipVisibilityScheduler(
        onShow: () => shows++,
        onHide: () {},
      );

      scheduler.onChildEnter(
        isShown: false,
        config: const TooltipScheduleConfig(),
      );

      expect(shows, 1);
      scheduler.dispose();
    });

    test('child enter with waitDuration delays show until elapsed', () {
      fakeAsync((async) {
        var shows = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () => shows++,
          onHide: () {},
        );

        scheduler.onChildEnter(
          isShown: false,
          config: const TooltipScheduleConfig(
            waitDuration: Duration(milliseconds: 200),
          ),
        );

        expect(shows, 0, reason: 'no show before waitDuration elapses');
        async.elapse(const Duration(milliseconds: 199));
        expect(shows, 0);
        async.elapse(const Duration(milliseconds: 1));
        expect(shows, 1, reason: 'shows exactly at waitDuration');

        scheduler.dispose();
      });
    });

    test('child exit before waitDuration cancels the pending show', () {
      fakeAsync((async) {
        var shows = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () => shows++,
          onHide: () {},
        );
        const config = TooltipScheduleConfig(
          waitDuration: Duration(milliseconds: 200),
        );

        scheduler.onChildEnter(isShown: false, config: config);
        async.elapse(const Duration(milliseconds: 100));
        scheduler.onChildExit(isShown: false, config: config);
        async.elapse(const Duration(milliseconds: 200));

        expect(shows, 0, reason: 'pending show cancelled by exit');
        scheduler.dispose();
      });
    });

    test('interactive child exit hides after the 100ms hover bridge', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () {},
          onHide: () => hides++,
        );

        scheduler.onChildExit(
          isShown: true,
          config: const TooltipScheduleConfig(interactive: true),
        );

        expect(hides, 0);
        async.elapse(const Duration(milliseconds: 99));
        expect(hides, 0, reason: 'still within the bridge window');
        async.elapse(const Duration(milliseconds: 1));
        expect(hides, 1, reason: 'hides at the 100ms bridge delay');

        scheduler.dispose();
      });
    });

    test('tooltip enter within the bridge cancels the pending hide', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(interactive: true);

        scheduler.onChildExit(isShown: true, config: config);
        async.elapse(const Duration(milliseconds: 50));
        scheduler.onTooltipEnter(config: config);
        async.elapse(const Duration(milliseconds: 200));

        expect(hides, 0, reason: 'cursor reached the tooltip in time');
        scheduler.dispose();
      });
    });

    test('non-interactive child exit hides immediately', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () {},
          onHide: () => hides++,
        );

        scheduler.onChildExit(
          isShown: true,
          config: const TooltipScheduleConfig(interactive: false),
        );

        expect(hides, 1, reason: 'no bridge when not interactive');
        scheduler.dispose();
      });
    });

    test('auto-hide fires onHide after showDuration', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () {},
          onHide: () => hides++,
        );

        scheduler.onChildEnter(
          isShown: false,
          config: const TooltipScheduleConfig(
            showDuration: Duration(seconds: 2),
          ),
        );

        expect(hides, 0);
        async.elapse(const Duration(seconds: 2));
        expect(hides, 1, reason: 'auto-hide fires at showDuration');

        scheduler.dispose();
      });
    });

    test('child exit does not bridge-hide when showDuration is set', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(
          interactive: true,
          showDuration: Duration(seconds: 5),
        );

        scheduler.onChildEnter(isShown: false, config: config);
        scheduler.onChildExit(isShown: true, config: config);
        async.elapse(const Duration(milliseconds: 200));

        expect(hides, 0, reason: 'auto-hide owns hiding, not the bridge');

        async.elapse(const Duration(seconds: 5));
        expect(hides, 1, reason: 'auto-hide still fires');
        scheduler.dispose();
      });
    });

    test('tooltip enter pauses auto-hide and tooltip exit resumes it', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(
          interactive: true,
          showDuration: Duration(seconds: 2),
        );

        scheduler.onChildEnter(isShown: false, config: config);
        async.elapse(const Duration(seconds: 1));
        scheduler.onTooltipEnter(config: config);
        async.elapse(const Duration(seconds: 5));
        expect(hides, 0, reason: 'auto-hide paused while cursor on tooltip');

        scheduler.onTooltipExit(isShown: true, config: config);
        async.elapse(const Duration(seconds: 2));
        expect(hides, 1, reason: 'auto-hide resumes after leaving tooltip');

        scheduler.dispose();
      });
    });

    test('tap toggles between show and hide requests', () {
      fakeAsync((async) {
        var shows = 0;
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () => shows++,
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig();

        scheduler.onTap(isShown: false, config: config);
        expect(shows, 1);
        expect(hides, 0);

        scheduler.onTap(isShown: true, config: config);
        expect(shows, 1);
        expect(hides, 1);

        scheduler.dispose();
      });
    });

    test('dispose cancels every pending timer — no callbacks fire after', () {
      void expectNoCallbacksAfterDispose(
        void Function(TooltipVisibilityScheduler) arm,
      ) {
        fakeAsync((async) {
          var shows = 0;
          var hides = 0;
          final scheduler = TooltipVisibilityScheduler(
            onShow: () => shows++,
            onHide: () => hides++,
          );

          arm(scheduler);
          final showsAtDispose = shows;
          final hidesAtDispose = hides;

          scheduler.dispose();
          async.elapse(const Duration(hours: 1));

          expect(shows, showsAtDispose, reason: 'no show fires after dispose');
          expect(hides, hidesAtDispose, reason: 'no hide fires after dispose');
        });
      }

      // Pending hover-show timer.
      expectNoCallbacksAfterDispose((s) => s.onChildEnter(
            isShown: false,
            config: const TooltipScheduleConfig(
              waitDuration: Duration(milliseconds: 200),
            ),
          ));
      // Pending hover-bridge hide timer.
      expectNoCallbacksAfterDispose((s) => s.onChildExit(
            isShown: true,
            config: const TooltipScheduleConfig(interactive: true),
          ));
      // Pending auto-hide timer.
      expectNoCallbacksAfterDispose((s) => s.onChildEnter(
            isShown: false,
            config: const TooltipScheduleConfig(
              showDuration: Duration(seconds: 2),
            ),
          ));
    });

    test('reset cancels pending timers but the scheduler stays usable', () {
      fakeAsync((async) {
        var shows = 0;
        final scheduler = TooltipVisibilityScheduler(
          onShow: () => shows++,
          onHide: () {},
        );

        scheduler.onChildEnter(
          isShown: false,
          config: const TooltipScheduleConfig(
            waitDuration: Duration(milliseconds: 200),
          ),
        );
        scheduler.reset();
        async.elapse(const Duration(seconds: 10));
        expect(shows, 0, reason: 'reset cancelled the pending show');

        // reset is not dispose — the scheduler still works afterward.
        scheduler.onChildEnter(
          isShown: false,
          config: const TooltipScheduleConfig(),
        );
        expect(shows, 1, reason: 'scheduler usable after reset');

        scheduler.dispose();
      });
    });
  });
}
