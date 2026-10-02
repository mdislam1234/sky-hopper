---
version: alpha
name: "Sky Hopper"
description: "A cheerful, cloud-layer arcade game whose interface stays readable while the sky and the run provide the spectacle."
colors:
  primary: "#123B69"
  sky: "#75CFFF"
  pale-sky: "#EAF8FF"
  deep-blue: "#123B69"
  cloud: "#FFFFFF"
  gold: "#FFD45A"
  orange: "#FF9F1C"
  coral: "#FF6F61"
  royal-blue: "#2D84FF"
  purple: "#8067E8"
typography:
  display:
    fontFamily: "Roboto, system-ui, sans-serif"
  body:
    fontFamily: "Roboto, system-ui, sans-serif"
rounded:
  control: "1.5rem"
  logo: "1.875rem"
  feedback: "1rem"
spacing:
  page-inline: "1.5rem"
  page-block: "2rem"
  content-max: "27.5rem"
components:
  button:
    height: "3.75rem"
  icon-button:
    size: "3rem"
  card: {}
  feedback-overlay: {}
---

# Sky Hopper Design System

## Overview

### Creative North Star

The interface is a compact arcade cabinet floating in a bright illustrated sky. Puffy cloud surfaces, deep-blue controls, and a single coin-gold action color echo the game world without competing with movement inside the playfield.

### Product context and register

- **Audience and primary job:** Casual Web and Android players need to reach play immediately as a guest, understand optional account protection, read score and hazards at a glance, and recover cleanly from pause or Game Over.
- **Target markets and evidence:** The product is currently an English-language global game; the repository defines no market-specific business behavior.
- **Locale and language policy:** English UI is canonical. Player-supplied names remain data and do not change control labels.
- **Usage scene:** Short portrait-first play sessions with keyboard or touch controls, plus responsive landscape and desktop layouts.
- **Register:** Hybrid. Menus favor familiar product controls; gameplay carries the expressive biome, particle, audio, and feedback language.
- **Memorable signature:** The cloud-framed double-arrow logo and sky gradient establish upward motion before a run starts.
- **Restraint:** Settings, authentication, persistence status, and error recovery use quiet Material controls and direct language.
- **Anti-references:** Avoid dark competitive dashboards, casino reward styling, dense utility panels, and visual effects that obscure the player or hazards.
- **Token ownership/runtime mapping:** This file mirrors the canonical Flutter values in `lib/core/theme/app_colors.dart`, `lib/core/theme/app_theme.dart`, and shared widgets under `lib/core/widgets/`. Runtime Dart remains the executable source of truth; durable token changes update both locations together.

## Colors

`sky` and `pale-sky` form the vertical background gradient. `deep-blue` carries text, icons, focus contrast, and secondary controls. `cloud` is the high-contrast surface. `gold` is reserved for primary actions, coins, and earned highlights such as a new personal best. Essential state is always accompanied by text or iconography rather than color alone.

## Typography

Material's Roboto/system fallback is used for both roles. Display text earns character through heavy weight, uppercase labels, and measured letter spacing; body text stays sentence case and plain. Scores and short status labels use strong weight for glance reading. Long prose and decorative italics do not belong in the game flow.

## Layout

Shared menu pages respect platform safe areas, scroll as one document, use 24px horizontal and 32px vertical padding, and center a 440px maximum-width content column. Gameplay follows the device orientation and fills the available safe area. Its responsive Flame viewport preserves a 400×720 fairness lane and uniform sprite scale while revealing additional biome scenery along the longer axis, so portrait and landscape never use gutters or stretch game art. HUD content remains compact, controls stay near the lower corners, and transient streak/near-miss notices appear away from the player.

## Elevation & Depth

The sky gradient and white cloud silhouettes provide environmental depth. Cards use Material tonal elevation. The logo alone receives a soft deep-blue shadow to float above the background. Gameplay overlays use a translucent deep-blue scrim so pause and Game Over remain readable without replacing the scene.

## Shapes

Large controls use a 24px rounded rectangle, the logo uses 30px corners, and transient feedback uses 16px corners. These shapes suggest clouds while retaining clear rectangular hit areas. Dividers inside settings stay thin and quiet.

## Components

### Foundational visual states

Flutter Material components own focus, hover, press, selected, disabled, and adaptive switch behavior. Enabled icon and text buttons provide at least 48px targets. Async save states keep actions stable and announce saving, success, or retry guidance in text.

### Buttons and actions

Gold filled buttons indicate the primary next action. Tonal or text treatments carry pause, back, profile, and secondary navigation. Icons support labels; unfamiliar icon-only controls require a tooltip and semantic name. Dangerous or irreversible controls are outside the Phase 11 game-feel surface.

### Navigation and data display

Home uses a large stacked wordmark with the existing Sky Hopper mascot art and a short `JUMP HIGHER` tagline. A single white player/coin bar and raised gold PLAY action lead into a responsive two-column grid for Daily Challenge, Missions, Achievements, Leaderboard, Skins, and Profile. Color is concentrated in the icon badges, while a single centered Settings tile closes the menu. The standard endless run remains the fastest path into play, and the grid may collapse for narrow layouts with enlarged text. Daily, weekly, and all-time competition belongs on pre-run and leaderboard screens; active gameplay keeps only score, coins, best, and the short mode label. Perfect streak, near miss, biome, and best-chase feedback stays transient to avoid crowding narrow screens.

Daily challenge cards state the UTC date, shared-course rule, ranked attempts remaining, personal best, top score, and whether the next run is ranked or unsaved practice. Mission and achievement cards share one visual grammar: an original Material-icon badge, a short goal, visible progress, a modest coin reward, and an explicit claim state. Completed, claimed, and locked states always use text as well as color. Competition surfaces keep the existing sky-and-cloud language rather than adopting a dense dashboard or casino presentation.

### Forms and overlays

Settings uses adaptive switches with a title, a short consequence, and a supporting icon. Pause and Game Over use the same centered overlay pattern and keep Restart/Resume and Home reachable. Their score, coin, and action labels stay on one line and scale down inside full-width controls on compact phones or with larger text. Save errors remain inline with an explicit retry action.

Startup is guest-first: a missing session creates an authenticated Supabase anonymous user, while an existing guest or Google session is preserved. Home identifies a guest as `Guest Player` without an account prompt. Profile contains the single optional Google-link action, a short protection benefit, and the uninstall/app-data warning. Linking must keep the current authenticated owner and progress; it never starts a separate Google sign-in that silently abandons guest data.

Android Settings may add Google's `Privacy Options` row only when UMP requires the entry point. It follows the existing ListTile grammar and opens the provider-owned form; no custom consent card or disable-ads switch belongs here.

At normal-mode Game Over, the optional outlined reward slot appears only after an eligible coin-collecting run is server-saved. It shows a disabled checking/loading state until the rewarded ad is ready, then becomes `WATCH VIDEO · +N COINS`; a restrained unavailable state offers retry after a load failure. It disappears after consumption or claim. The filled Restart and text Home actions remain visible and usable throughout. Claiming uses plain progress and server-confirmed success/retry text. Advertising never uses the gold primary treatment, countdown pressure, false scarcity, or a control that resembles gameplay rewards. Daily Challenge, unsaved runs, active gameplay, pause, Login, and Web contain no ad actions.

### Iconography

Use rounded Material icons at their standard optical weight. Icons reinforce familiar actions and hazards but never replace essential labels or visible lightning warnings.

### Motion

Motion communicates bounce, collection, hazard impact, biome change, and earned milestones. Effects are short, interruptible, and bounded. Reduced-motion mode disables screen shake, removes decorative near-miss particles, reduces celebratory counts, and keeps text/audio feedback available independently.

### Content and data visualization

The voice is brief and arcade-direct: `PLAY`, `PERFECT!`, `CLOSE!`, `NEW BEST!`, and concrete save recovery. Persisted score remains the upward-progress integer, and coin values retain their existing economy.

Progression labels use equally direct language: `PLAY DAILY`, `PRACTICE DAILY`, `COMPLETE`, `CLAIM`, and `CLAIMED`. Server-confirmed state is never implied before a successful response. Network failures keep previously confirmed information visible when possible and provide a short retry message without inventing attempts, rewards, or ranks.

## Do's and Don'ts

- **Do:** Let the biome and gameplay events provide the strongest audiovisual expression.
- **Do:** Reuse shared page, menu, HUD, overlay, and theme primitives across routes.
- **Don't:** cover the player, hazards, or core controls with celebratory feedback.
- **Don't:** imply a local run best is server-confirmed before result persistence succeeds.
