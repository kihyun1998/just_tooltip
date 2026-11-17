import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/src/tooltip_visibility_scheduler.dart';

void main() {
  group('TooltipVisibilityScheduler', () {
    test('child enter with no waitDuration shows immediately', () {
      var shows = 0;
      final scheduler = TooltipVisibilityScheduler(
        onWaitElapsed: () {},
        onShow: () => shows++,
        onHide: () {},
      );

      scheduler.onChildEnter(
        pointerOnBody: false,
        isShown: false,
        config: const TooltipScheduleConfig(),
      );

      expect(shows, 1);
      scheduler.dispose();
    });

    test('child enter with waitDuration requests the wait\'s end once it '
        'elapses, and shows nothing itself', () {
      fakeAsync((async) {
        var shows = 0;
        var waits = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () => waits++,
          onShow: () => shows++,
          onHide: () {},
        );

        scheduler.onChildEnter(
          pointerOnBody: false,
          isShown: false,
          config: const TooltipScheduleConfig(
            waitDuration: Duration(milliseconds: 200),
          ),
        );

        expect(waits, 0, reason: 'nothing before waitDuration elapses');
        async.elapse(const Duration(milliseconds: 199));
        expect(waits, 0);
        async.elapse(const Duration(milliseconds: 1));
        expect(waits, 1, reason: 'the wait ends exactly at waitDuration');
        expect(shows, 0, reason: 'the caller answers with showAfterWait');

        scheduler.dispose();
      });
    });

    test('showAfterWait shows and starts the countdown from the config it is '
        'given', () {
      fakeAsync((async) {
        var shows = 0;
        var closes = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () => shows++,
          onHide: () {},
          onClose: () => closes++,
        );

        scheduler.onChildEnter(
          pointerOnBody: false,
          isShown: false,
          config: const TooltipScheduleConfig(
            waitDuration: Duration(milliseconds: 200),
          ),
        );
        async.elapse(const Duration(milliseconds: 200));
        scheduler.showAfterWait(
          pointerOnBody: false,
          config: const TooltipScheduleConfig(
            waitDuration: Duration(milliseconds: 200),
            showDuration: Duration(milliseconds: 300),
          ),
        );
        expect(shows, 1);
        async.elapse(const Duration(milliseconds: 299));
        expect(closes, 0);
        async.elapse(const Duration(milliseconds: 1));
        expect(closes, 1, reason: 'the countdown read the showDuration given');

        scheduler.showAfterWait(
          pointerOnBody: true,
          config: const TooltipScheduleConfig(
            showDuration: Duration(milliseconds: 300),
          ),
        );
        async.elapse(const Duration(seconds: 1));
        expect(closes, 1, reason: 'paused while the pointer is on the body');

        scheduler.dispose();
      });
    });

    test('child enter with waitDuration while shown shows immediately', () {
      fakeAsync((async) {
        var shows = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () => shows++,
          onShow: () => shows++,
          onHide: () {},
        );

        scheduler.onChildEnter(
          pointerOnBody: false,
          isShown: true,
          config: const TooltipScheduleConfig(
            waitDuration: Duration(milliseconds: 200),
          ),
        );

        expect(shows, 1, reason: 'no wait for a tooltip already shown');
        async.elapse(const Duration(milliseconds: 400));
        expect(shows, 1, reason: 'no second show when the wait would end');

        scheduler.dispose();
      });
    });

    test('a programmatic show cancels the pending hover show', () {
      fakeAsync((async) {
        var shows = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () => shows++,
          onShow: () => shows++,
          onHide: () {},
        );
        const config = TooltipScheduleConfig(
          waitDuration: Duration(milliseconds: 200),
        );

        scheduler.onChildEnter(
          pointerOnBody: false,
          isShown: false,
          config: config,
        );
        async.elapse(const Duration(milliseconds: 100));
        scheduler.onProgrammaticShow(pointerOnBody: false, config: config);
        async.elapse(const Duration(milliseconds: 400));

        expect(shows, 0, reason: 'the controller show answered it');
        scheduler.dispose();
      });
    });

    test('a programmatic show cancels an armed hover bridge', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(interactive: true);

        scheduler.onChildExit(
          hoverOnBody: false,
          isShown: true,
          config: config,
        );
        async.elapse(const Duration(milliseconds: 40));
        scheduler.onProgrammaticShow(pointerOnBody: false, config: config);
        async.elapse(const Duration(seconds: 1));

        expect(hides, 0, reason: 'the controller show outranks the bridge');
        scheduler.dispose();
      });
    });

    test('child exit before waitDuration cancels the pending show', () {
      fakeAsync((async) {
        var shows = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () => shows++,
          onShow: () => shows++,
          onHide: () {},
        );
        const config = TooltipScheduleConfig(
          waitDuration: Duration(milliseconds: 200),
        );

        scheduler.onChildEnter(
          pointerOnBody: false,
          isShown: false,
          config: config,
        );
        async.elapse(const Duration(milliseconds: 100));
        scheduler.onChildExit(
          hoverOnBody: false,
          isShown: false,
          config: config,
        );
        async.elapse(const Duration(milliseconds: 200));

        expect(shows, 0, reason: 'pending show cancelled by exit');
        scheduler.dispose();
      });
    });

    test('interactive child exit hides after the 100ms hover bridge', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );

        scheduler.onChildExit(
          hoverOnBody: false,
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
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(interactive: true);

        scheduler.onChildExit(
          hoverOnBody: false,
          isShown: true,
          config: config,
        );
        async.elapse(const Duration(milliseconds: 50));
        scheduler.onTooltipEnter(turnBack: false, config: config);
        async.elapse(const Duration(milliseconds: 200));

        expect(hides, 0, reason: 'cursor reached the tooltip in time');
        scheduler.dispose();
      });
    });

    test('tooltip enter with enableHover off leaves an armed bridge to run '
        'out, and still pauses the auto-hide', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(enableHover: false);

        scheduler.onChildExit(
          hoverOnBody: false,
          isShown: true,
          config: config,
        );
        async.elapse(const Duration(milliseconds: 50));
        scheduler.onTooltipEnter(turnBack: false, config: config);
        async.elapse(const Duration(milliseconds: 49));
        expect(hides, 0, reason: 'the bridge is still waiting');
        async.elapse(const Duration(milliseconds: 1));
        expect(hides, 1, reason: 'the entry did not cancel the bridge');

        var closes = 0;
        final countdown = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () {},
          onClose: () => closes++,
        );
        const timed = TooltipScheduleConfig(
          enableHover: false,
          showDuration: Duration(milliseconds: 100),
        );
        countdown.startAutoHide(timed, pointerOnBody: false);
        countdown.onTooltipEnter(turnBack: false, config: timed);
        async.elapse(const Duration(milliseconds: 500));
        expect(closes, 0, reason: 'the entry paused the countdown');

        scheduler.dispose();
        countdown.dispose();
      });
    });

    test('a child exit with a hover-entered pointer on the body asks for no '
        'hide', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );

        for (final interactive in [true, false]) {
          scheduler.onChildExit(
            hoverOnBody: true,
            isShown: true,
            config: TooltipScheduleConfig(interactive: interactive),
          );
          async.elapse(const Duration(milliseconds: 500));
        }
        expect(hides, 0, reason: 'the body holds it');

        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: true,
          exitLeftToCountdown: false,
          config: const TooltipScheduleConfig(),
        );
        async.elapse(const Duration(milliseconds: 99));
        expect(hides, 0, reason: 'the bridge is waiting');
        async.elapse(const Duration(milliseconds: 1));
        expect(hides, 1, reason: "the body's exit armed the bridge");

        scheduler.dispose();
      });
    });

    test('non-interactive child exit hides immediately', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );

        scheduler.onChildExit(
          hoverOnBody: false,
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
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );

        scheduler.onChildEnter(
          pointerOnBody: false,
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
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(
          interactive: true,
          showDuration: Duration(seconds: 5),
        );

        scheduler.onChildEnter(
          pointerOnBody: false,
          isShown: false,
          config: config,
        );
        scheduler.onChildExit(
          hoverOnBody: false,
          isShown: true,
          config: config,
        );
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
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(
          interactive: true,
          showDuration: Duration(seconds: 2),
        );

        scheduler.onChildEnter(
          pointerOnBody: false,
          isShown: false,
          config: config,
        );
        async.elapse(const Duration(seconds: 1));
        scheduler.onTooltipEnter(turnBack: false, config: config);
        async.elapse(const Duration(seconds: 5));
        expect(hides, 0, reason: 'auto-hide paused while cursor on tooltip');

        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: true,
          exitLeftToCountdown: false,
          config: config,
        );
        async.elapse(const Duration(seconds: 2));
        expect(hides, 1, reason: 'auto-hide resumes after leaving tooltip');

        scheduler.dispose();
      });
    });

    test('tooltip exit resumes the auto-hide tooltip enter paused whatever '
        'hover and interactive are, and arms no bridge without hover', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );
        const timed = TooltipScheduleConfig(
          enableHover: false,
          showDuration: Duration(seconds: 2),
        );

        scheduler.onTap(pointerOnBody: false, isShown: false, config: timed);
        scheduler.onTooltipEnter(turnBack: false, config: timed);
        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: false,
          exitLeftToCountdown: false,
          config: timed,
        );
        async.elapse(const Duration(milliseconds: 1900));
        expect(hides, 0, reason: 'the countdown restarted on leaving');
        async.elapse(const Duration(milliseconds: 200));
        expect(hides, 1, reason: 'auto-hide resumes after leaving tooltip');

        const untimed = TooltipScheduleConfig(enableHover: false);
        scheduler.onTooltipEnter(turnBack: false, config: untimed);
        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: false,
          exitLeftToCountdown: false,
          config: untimed,
        );
        async.elapse(const Duration(seconds: 1));
        expect(hides, 1, reason: 'no hover policy, so no bridge');

        // `interactive` turned off while the pointer rested on the body.
        const blocked = TooltipScheduleConfig(
          interactive: false,
          showDuration: Duration(seconds: 2),
        );
        scheduler.onTooltipEnter(
          turnBack: false,
          config: const TooltipScheduleConfig(
            showDuration: Duration(seconds: 2),
          ),
        );
        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: true,
          exitLeftToCountdown: false,
          config: blocked,
        );
        async.elapse(const Duration(milliseconds: 2100));
        expect(hides, 2, reason: 'the pause ends with the pointer leaving');

        scheduler.dispose();
      });
    });

    test('tooltip exit with interactive off and no showDuration hides at '
        'once under hover, and does nothing without it', () {
      fakeAsync((async) {
        var hides = 0;
        var closes = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
          onClose: () => closes++,
        );

        scheduler.onTooltipEnter(
          turnBack: false,
          config: const TooltipScheduleConfig(),
        );
        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: true,
          exitLeftToCountdown: false,
          config: const TooltipScheduleConfig(interactive: false),
        );
        expect(hides, 1, reason: 'no bridge: the hide is requested at once');
        async.elapse(const Duration(seconds: 1));
        expect(hides, 1, reason: 'and no bridge fires later');

        scheduler.onTooltipEnter(
          turnBack: false,
          config: const TooltipScheduleConfig(enableHover: false),
        );
        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: false,
          exitLeftToCountdown: false,
          config: const TooltipScheduleConfig(
            enableHover: false,
            interactive: false,
          ),
        );
        async.elapse(const Duration(seconds: 1));
        expect(hides, 1, reason: 'no hover policy, so no hide');
        expect(closes, 0, reason: 'leaving is not a close');

        scheduler.dispose();
      });
    });

    test('tooltip exit after an entry made with hover on hides at once '
        'though hover is now off, and arms no bridge', () {
      fakeAsync((async) {
        var hides = 0;
        var closes = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
          onClose: () => closes++,
        );

        for (final interactive in [true, false]) {
          scheduler.onTooltipEnter(
            turnBack: false,
            config: const TooltipScheduleConfig(),
          );
          scheduler.onTooltipExit(
            isShown: true,
            enteredWithHover: true,
            exitLeftToCountdown: false,
            config: TooltipScheduleConfig(
              enableHover: false,
              interactive: interactive,
            ),
          );
        }
        expect(hides, 2, reason: 'each exit requests the hide at once');
        async.elapse(const Duration(seconds: 1));
        expect(hides, 2, reason: 'and no bridge fires later');
        expect(closes, 0, reason: 'leaving is not a close');

        scheduler.dispose();
      });
    });

    test('no show starts the auto-hide while the pointer is on the body; '
        'tooltip exit does', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(
          showDuration: Duration(seconds: 1),
        );

        scheduler.onProgrammaticShow(pointerOnBody: false, config: config);
        scheduler.onTooltipEnter(turnBack: false, config: config);
        scheduler.onProgrammaticShow(pointerOnBody: true, config: config);
        scheduler.onChildEnter(
          isShown: true,
          pointerOnBody: true,
          config: config,
        );
        async.elapse(const Duration(seconds: 5));
        expect(hides, 0, reason: 'paused while the pointer is on the body');

        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: true,
          exitLeftToCountdown: false,
          config: config,
        );
        async.elapse(const Duration(milliseconds: 900));
        expect(hides, 0);
        async.elapse(const Duration(milliseconds: 200));
        expect(hides, 1, reason: 'the countdown starts on leaving the body');

        scheduler.dispose();
      });
    });

    test('tooltip enter with turnBack requests a show and pauses the '
        'auto-hide', () {
      fakeAsync((async) {
        var shows = 0;
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () => shows++,
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig(
          showDuration: Duration(seconds: 1),
        );

        scheduler.onTooltipEnter(turnBack: false, config: config);
        expect(shows, 0);
        scheduler.onTooltipEnter(turnBack: true, config: config);
        expect(shows, 1);
        async.elapse(const Duration(seconds: 5));
        expect(hides, 0, reason: 'paused while the pointer is on the body');

        scheduler.dispose();
      });
    });

    test('tap toggles between show and hide requests', () {
      fakeAsync((async) {
        var shows = 0;
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () => shows++,
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig();

        scheduler.onTap(pointerOnBody: false, isShown: false, config: config);
        expect(shows, 1);
        expect(hides, 0);

        scheduler.onTap(pointerOnBody: false, isShown: true, config: config);
        expect(shows, 1);
        expect(hides, 1);

        scheduler.dispose();
      });
    });

    test('a tap and the auto-hide request onClose; a child exit and the '
        'bridge request onHide', () {
      fakeAsync((async) {
        final calls = <String>[];
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => calls.add('hide'),
          onClose: () => calls.add('close'),
        );

        scheduler.onTap(
          pointerOnBody: false,
          isShown: true,
          config: const TooltipScheduleConfig(),
        );
        scheduler.startAutoHide(
          pointerOnBody: false,
          const TooltipScheduleConfig(showDuration: Duration(seconds: 1)),
        );
        async.elapse(const Duration(seconds: 1));
        scheduler.onChildExit(
          hoverOnBody: false,
          isShown: true,
          config: const TooltipScheduleConfig(interactive: false),
        );
        scheduler.onChildExit(
          hoverOnBody: false,
          isShown: true,
          config: const TooltipScheduleConfig(interactive: true),
        );
        async.elapse(const Duration(milliseconds: 100));

        expect(calls, ['close', 'close', 'hide', 'hide']);
        scheduler.dispose();
      });
    });

    test('a showDuration change restarts the auto-hide from the change, '
        'paused while the pointer is on the body', () {
      fakeAsync((async) {
        final calls = <String>[];
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => calls.add('hide'),
          onClose: () => calls.add('close'),
        );
        const long = TooltipScheduleConfig(showDuration: Duration(seconds: 2));
        const short = TooltipScheduleConfig(
          showDuration: Duration(milliseconds: 500),
        );

        // Set on a tooltip shown with none.
        scheduler.onProgrammaticShow(
          pointerOnBody: false,
          config: const TooltipScheduleConfig(),
        );
        async.elapse(const Duration(seconds: 1));
        scheduler.onShowDurationChange(
          pointerOnBody: false,
          exitLeftToCountdown: false,
          config: long,
        );
        async.elapse(const Duration(milliseconds: 1900));
        expect(calls, isEmpty, reason: 'counted from the change');
        async.elapse(const Duration(milliseconds: 200));
        expect(calls, ['close']);

        // Changed: the previous countdown is replaced.
        calls.clear();
        scheduler.onProgrammaticShow(pointerOnBody: false, config: long);
        async.elapse(const Duration(seconds: 1));
        scheduler.onShowDurationChange(
          pointerOnBody: false,
          exitLeftToCountdown: false,
          config: short,
        );
        async.elapse(const Duration(milliseconds: 600));
        expect(calls, ['close'], reason: 'the shorter one, from the change');
        async.elapse(const Duration(seconds: 2));
        expect(calls, ['close'], reason: 'the old countdown is gone');

        // With the pointer on the body it stays paused until the exit.
        calls.clear();
        scheduler.onShowDurationChange(
          pointerOnBody: true,
          exitLeftToCountdown: false,
          config: short,
        );
        async.elapse(const Duration(seconds: 2));
        expect(calls, isEmpty, reason: 'paused while the pointer is on it');

        scheduler.dispose();
      });
    });

    test('showDuration cleared cancels the auto-hide and asks for the hide a '
        'trigger exit left to it', () {
      fakeAsync((async) {
        final calls = <String>[];
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => calls.add('hide'),
          onClose: () => calls.add('close'),
        );
        const timed = TooltipScheduleConfig(
          showDuration: Duration(milliseconds: 500),
        );
        const untimed = TooltipScheduleConfig();

        // No exit left to it: the countdown is cancelled, nothing else.
        scheduler.onProgrammaticShow(pointerOnBody: false, config: timed);
        scheduler.onShowDurationChange(
          pointerOnBody: false,
          exitLeftToCountdown: false,
          config: untimed,
        );
        async.elapse(const Duration(seconds: 2));
        expect(calls, isEmpty, reason: 'the countdown was cancelled');

        // An exit left to it, the pointer off the body: the Hover Bridge.
        scheduler.onProgrammaticShow(pointerOnBody: false, config: timed);
        scheduler.onShowDurationChange(
          pointerOnBody: false,
          exitLeftToCountdown: true,
          config: untimed,
        );
        async.elapse(const Duration(milliseconds: 90));
        expect(calls, isEmpty, reason: 'the bridge, as onChildExit arms');
        async.elapse(const Duration(milliseconds: 20));
        expect(calls, ['hide'], reason: 'a trigger exit, not a close');
        async.elapse(const Duration(seconds: 1));
        expect(calls, ['hide'], reason: 'the countdown was cancelled');

        // Non-interactive: at once.
        calls.clear();
        scheduler.onShowDurationChange(
          pointerOnBody: false,
          exitLeftToCountdown: true,
          config: const TooltipScheduleConfig(interactive: false),
        );
        expect(calls, ['hide']);

        // The pointer on the body: nothing until it leaves, and its exit asks
        // for the hide even with hover off and no entry made with it on.
        calls.clear();
        scheduler.onShowDurationChange(
          pointerOnBody: true,
          exitLeftToCountdown: true,
          config: untimed,
        );
        async.elapse(const Duration(seconds: 1));
        expect(calls, isEmpty, reason: 'the pointer still rests on the body');
        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: false,
          exitLeftToCountdown: true,
          config: const TooltipScheduleConfig(enableHover: false),
        );
        async.elapse(const Duration(milliseconds: 110));
        expect(calls, ['hide']);

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
            onWaitElapsed: () => shows++,
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
      expectNoCallbacksAfterDispose(
        (s) => s.onChildEnter(
          isShown: false,
          pointerOnBody: false,
          config: const TooltipScheduleConfig(
            waitDuration: Duration(milliseconds: 200),
          ),
        ),
      );
      // Pending hover-bridge hide timer.
      expectNoCallbacksAfterDispose(
        (s) => s.onChildExit(
          hoverOnBody: false,
          isShown: true,
          config: const TooltipScheduleConfig(interactive: true),
        ),
      );
      // Pending auto-hide timer.
      expectNoCallbacksAfterDispose(
        (s) => s.onChildEnter(
          isShown: false,
          pointerOnBody: false,
          config: const TooltipScheduleConfig(
            showDuration: Duration(seconds: 2),
          ),
        ),
      );
    });

    test('reset cancels pending timers but the scheduler stays usable', () {
      fakeAsync((async) {
        var shows = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () => shows++,
          onShow: () => shows++,
          onHide: () {},
        );

        scheduler.onChildEnter(
          pointerOnBody: false,
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
          pointerOnBody: false,
          isShown: false,
          config: const TooltipScheduleConfig(),
        );
        expect(shows, 1, reason: 'scheduler usable after reset');

        scheduler.dispose();
      });
    });
    test('child enter cancels a bridge armed by leaving the tooltip', () {
      fakeAsync((async) {
        var hides = 0;
        final scheduler = TooltipVisibilityScheduler(
          onWaitElapsed: () {},
          onShow: () {},
          onHide: () => hides++,
        );
        const config = TooltipScheduleConfig();

        // The cursor crosses child -> tooltip body -> back to the child.
        scheduler.onChildExit(
          hoverOnBody: false,
          isShown: true,
          config: config,
        );
        scheduler.onTooltipEnter(turnBack: false, config: config);
        scheduler.onTooltipExit(
          isShown: true,
          enteredWithHover: true,
          exitLeftToCountdown: false,
          config: config,
        );
        scheduler.onChildEnter(
          pointerOnBody: false,
          isShown: true,
          config: config,
        );

        async.elapse(const Duration(seconds: 1));

        expect(
          hides,
          0,
          reason: 'the pointer is back on the child; nothing to bridge to',
        );
        scheduler.dispose();
      });
    });
  });
}
