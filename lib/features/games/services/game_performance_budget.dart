/// Performance guardrails shared by the games UI and its regression tests.
class GamePerformanceBudget {
  GamePerformanceBudget._();

  static const catalogSize = 55;
  static const maxAnimationMilliseconds = 300;
  static const targetFrameMilliseconds = 16;
  static const maxParticlesPerBurst = 24;

  static bool isAnimationWithinBudget(Duration duration) =>
      duration.inMilliseconds <= maxAnimationMilliseconds;
}
