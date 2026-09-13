# Emil Kowalski UI Craftsmanship, Animation & Design Engineering Guidelines

## Core Principles
1. **Design Engineering**: Every interaction should feel intentional, natural, and responsive.
2. **Animation Principles**:
   - Never animate layout-triggering properties (`top`, `left`, `width`, `height`) when transforms (`transform: translate/scale`) can be used.
   - Use springs for interactive/gesture animations, and smooth ease-out curves for programmatic transitions.
   - Durations: micro-interactions should take 150-250ms; modal transitions 250-350ms; never make the user wait for an animation to finish before they can interact.
3. **Typography & Hierarchy**:
   - High visual contrast where focus is needed.
   - Consistent typographic scale, tight tracking for large titles, normal for body.
4. **Touch & Click Feedback**:
   - Active scale down feedback on click/press (`scale(0.98)` or `scale(0.96)`).
   - Clear focus rings with proper outline offset.
   - Smooth hover transitions (`transition: all 0.2s cubic-bezier(...)`).
5. **Toast / Notification System (Sonner)**:
   - Floating, stacked, swipeable notifications with smooth dismissal and expansion on hover.
