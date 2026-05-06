# Agent Compatibility Rules

## Mobile Platform Compatibility

When working on SanDeVentura mobile features, implement with Android and iOS
compatibility in mind unless a task explicitly narrows the scope.

- Keep platform-specific code behind Flutter abstractions or small platform
  adapters.
- Add both Android and iOS permission/configuration changes when a plugin or
  native capability requires them.
- Prefer Flutter packages that support Android and iOS for MVP mobile features.
- Do not hard-code Android-only behavior into shared Dart code.
- Treat Android as the first field-test platform, but avoid choices that block
  a later iOS build without a documented reason.
- Document any platform limitation directly in the relevant plan or code review
  note before relying on it.
