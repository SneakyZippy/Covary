---
name: Traceloop 2026
colors:
  surface: '#0e1512'
  surface-dim: '#0e1512'
  surface-bright: '#333b38'
  surface-container-lowest: '#09100d'
  surface-container-low: '#161d1b'
  surface-container: '#1a211f'
  surface-container-high: '#242c29'
  surface-container-highest: '#2f3633'
  on-surface: '#dde4e0'
  on-surface-variant: '#bacac3'
  inverse-surface: '#dde4e0'
  inverse-on-surface: '#2b322f'
  outline: '#85948e'
  outline-variant: '#3c4a45'
  surface-tint: '#38debb'
  primary: '#ffffff'
  on-primary: '#00382d'
  primary-container: '#5ffbd6'
  on-primary-container: '#00725e'
  inverse-primary: '#006b58'
  secondary: '#cdbdff'
  on-secondary: '#370096'
  secondary-container: '#5203d5'
  on-secondary-container: '#c0acff'
  tertiary: '#ffffff'
  on-tertiary: '#393000'
  tertiary-container: '#fbe273'
  on-tertiary-container: '#756400'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#5ffbd6'
  primary-fixed-dim: '#38debb'
  on-primary-fixed: '#002019'
  on-primary-fixed-variant: '#005142'
  secondary-fixed: '#e8deff'
  secondary-fixed-dim: '#cdbdff'
  on-secondary-fixed: '#20005f'
  on-secondary-fixed-variant: '#4f00d0'
  tertiary-fixed: '#fbe273'
  tertiary-fixed-dim: '#dec65a'
  on-tertiary-fixed: '#211b00'
  on-tertiary-fixed-variant: '#534600'
  background: '#0e1512'
  on-background: '#dde4e0'
  surface-variant: '#2f3633'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  body-rel:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  label-caps:
    fontFamily: Space Grotesk
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.08em
  data-mono:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  margin-mobile: 20px
  gutter: 12px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
---

## Brand & Style

The design system is engineered for a 2026 mobile-first experience, focusing on personal well-being and high-integrity data analysis. The brand personality is clinical yet empathetic, evoking a sense of "digital sanctuary." It prioritizes a **privacy-first aesthetic**, using deep, immersive backgrounds to reduce eye strain and provide a canvas for critical data insights.

The style is a hybrid of **Glassmorphism** and **Corporate Modern**. It utilizes translucent layers to suggest depth and data transparency, while maintaining the structural rigor required for health metrics. Every interaction is designed to feel high-tech and precise, using "Elevated Neutrals" to establish a hierarchy that feels expensive and secure. Glowing active states act as biological "pulses" within the UI, signifying life and activity within the data.

## Colors

The palette is anchored in **Midnight Navy**, providing a low-light environment that emphasizes user privacy. **Aquamarine** serves as the primary action color, chosen for its high visibility and association with clarity and health. **Deep Violet** is used for secondary data streams and deep-focus modes, providing a sophisticated counterpoint to the primary teal.

"Elevated Neutrals" are defined as desaturated blues that bridge the gap between the deep background and the interactive accents. These are used for borders, inactive states, and subtle dividers to maintain a sleek, cohesive look without relying on harsh whites or greys. 
- **Active States:** Utilize a 15% opacity radial glow of the Primary or Secondary color.
- **Data Visualization:** Use the Saturated Green for positive trends and Soft Coral for warnings, ensuring they pop against the dark surfaces without causing visual fatigue.

## Typography

This design system utilizes **Inter** for its core communication due to its exceptional readability on mobile screens and neutral, utilitarian character. It provides a stable foundation for complex health data.

To inject a "high-tech" and "scientific" feel, **Space Grotesk** is introduced for labels, captions, and data points. Its geometric nature complements the well-being metrics and gives the app a futuristic edge. 
- **Hierarchy:** Headlines use tighter tracking and heavier weights to feel impactful. 
- **Data Points:** Numerical data should always use Space Grotesk to differentiate "intelligence" from "narrative" text.

## Layout & Spacing

The layout follows a **fluid grid** model optimized for mobile viewport constraints. A 4-column grid is used for handsets, with a 20px outer margin to ensure content feels contained and safe. 

Spacing follows a strict 4px base unit. 
- **Vertical Rhythm:** Elements are stacked using increments of 8px (2 units) to maintain a tight, technical density.
- **Touch Targets:** Minimum touch targets are set to 48px, even if the visual element is smaller, to ensure accessibility during active use-cases (e.g., walking or exercising).

## Elevation & Depth

Depth in this design system is achieved through **Tonal Layering** and **Subtle Glassmorphism** rather than traditional heavy shadows.
1. **Level 0 (Background):** Midnight Navy (#0B1120).
2. **Level 1 (Cards/Surfaces):** Layered Navy (#162032). These surfaces feature a 1px inner border of #2D3748 at 40% opacity to define edges.
3. **Level 2 (Modals/Popovers):** Surface color with a backdrop blur of 20px and a subtle outer glow (0px 4px 20px) using a 10% opacity version of the Primary Accent.

Avoid drop shadows. Use "Object-Source" lighting, where elements higher in the stack have slightly lighter fills and more pronounced inner-glows on the top edge.

## Shapes

The shape language is **Rounded (Level 2)**, creating a balance between the precision of technology and the softness of well-being.
- **Standard Cards:** 1rem (16px) corner radius.
- **Interactive Elements (Buttons/Inputs):** 0.75rem (12px) corner radius.
- **Status Indicators:** Full pill-shape for chips and tags to contrast against the structured card edges.

This mix of radii ensures the UI feels approachable ("Soft") but maintains enough structural integrity to look like a professional data tool.

## Components

### Buttons
Primary buttons use a subtle vertical gradient of the Primary Accent to a slightly darker teal. The text is Midnight Navy for maximum contrast. Active states trigger an external "Cyan Glow" (Bloom effect). Secondary buttons are outlined with a 1px "Elevated Neutral" border.

### Cards
Cards are the primary data container. They should use the `#162032` surface color. For high-priority metrics, a 2px top-border of the Secondary Accent (Deep Violet) is applied to signify "Insight" status.

### Inputs & Fields
Input fields are dark-filled with a subtle inner-shadow to appear recessed. On focus, the border transitions to the Primary Accent with a soft 4px outer glow. Labels are always rendered in Space Grotesk (Caps).

### Wellbeing Visualizers
Include "Pulse" charts—line graphs that use the Primary Accent with a gradient-fill area underneath. Points on the graph should have a soft bloom effect to look like glowing bio-markers.

### Privacy Shields
A unique component for this design system: a "Locked" state overlay using a 40px backdrop blur and a centered "Privacy" icon in Aquamarine, used when sensitive health data is obscured from view.