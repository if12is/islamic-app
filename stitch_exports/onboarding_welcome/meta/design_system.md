# Design System Document: The Sacred Minimalist

## 1. Overview & Creative North Star
**Creative North Star: "The Modern Sanctuary"**

This design system rejects the cluttered, literal interpretations of traditional spiritual apps in favor of an editorial, high-end experience. We are building a "Digital Sanctuary"—a space that feels expansive, quiet, and intentional. 

The aesthetic moves beyond standard Material 3 by utilizing **Intentional Asymmetry** and **Tonal Depth**. By leveraging the Cairo typeface’s architectural qualities and a strict RTL-first logic, we create a layout that breathes. We break the "template" look by avoiding rigid borders and instead using light, shadow, and soft color shifts to guide the user’s journey.

---

## 2. Colors & Atmospheric Tones
Our palette is rooted in the deep history of Islamic art but applied with modern restraint. 

### Color Palette (Material 3 Mapping)
- **Primary / Primary Container:** Use `primary` (#003527) for high-impact brand moments and `primary_container` (#064e3b) for deep, immersive backgrounds.
- **Tertiary (The Accent):** Use `tertiary` (#735c00) and `tertiary_fixed` (#ffe088) for soft gold highlights, mimicking the "Noor" (light) of sacred manuscripts.
- **Surface & Background:** The foundation is `surface` (#f9f9f9). 

### The "No-Line" Rule
**Prohibit 1px solid borders for sectioning.** Boundaries must be defined solely through background color shifts. To separate a prayer time card from the main feed, use `surface_container_low` against a `surface` background. 

### The "Glass & Gradient" Rule
To avoid a flat, "out-of-the-box" feel, use **Glassmorphism** for floating elements (e.g., a Bottom Navigation Bar). Apply a semi-transparent `surface_container_lowest` with a 20px backdrop blur. For Hero sections, use a subtle radial gradient transitioning from `primary` (#003527) to `primary_container` (#064e3b) to provide a "soulful" depth.

---

## 3. Typography: The Cairo Monolith
We use **Cairo** exclusively. It is a font that bridges the gap between Kufic geometry and modern sans-serif readability.

| Level | Token | Size | Weight | Intent |
| :--- | :--- | :--- | :--- | :--- |
| **Display** | `display-lg` | 3.5rem | Bold | Editorial Quranic verses or Daily Ayah. |
| **Headline** | `headline-md` | 1.75rem | Medium | Section headers (e.g., "Prayer Times"). |
| **Title** | `title-lg` | 1.375rem | Bold | Card titles and prominent navigation. |
| **Body** | `body-lg` | 1.0rem | Regular | General reading and long-form text. |
| **Label** | `label-md` | 0.75rem | Medium | Utility text, timestamps, and metadata. |

**Editorial Note:** Use `display-lg` with a negative letter-spacing (-0.02em) for a high-end, bespoke feel in hero sections.

---

## 4. Elevation & Depth: Tonal Layering
Traditional drop shadows are forbidden. We use **Ambient Layering** to create a sense of physical presence.

- **The Layering Principle:** Stack `surface-container` tiers. Place a `surface_container_lowest` (pure white) card on a `surface_container_low` section. This creates a soft, natural lift without "heavy" UI.
- **Ambient Shadows:** For floating action buttons or high-priority modals, use a shadow color tinted with the `primary` hue at 4% opacity with a Blur of 32px and Y-offset of 8px.
- **The "Ghost Border" Fallback:** If a container requires definition against a similar color, use the `outline_variant` token at **15% opacity**. Never use a 100% opaque border.
- **Geometric Motifs:** Integrate subtle, 2% opacity geometric patterns (Mashrabiya) within `primary_container` backgrounds to provide texture without distracting from the content.

---

## 5. Components & Flutter Implementation
All components must support **RTL (Right-to-Left)** out of the box.

### Buttons (High-End Precision)
- **Primary:** Filled with `primary`, utilizing a `xl` (1.5rem) roundedness scale. No shadow.
- **Secondary:** Tonal button using `secondary_container`.
- **Tertiary:** Text-only using `tertiary` (Gold), reserved for "View All" or "Skip" actions.

### Cards & Lists (The Divider-Free Philosophy)
- **Cards:** Use `surface_container_lowest`. Forbid the use of divider lines. 
- **Separation:** Use vertical white space (Token `6`: 2rem) or a subtle shift to `surface_container_high` to separate content blocks.
- **Leading/Trailing:** In RTL, the "Leading" element (e.g., an icon) must be on the right, and "Trailing" (e.g., a chevron) on the left.

### Sacred Input Fields
- **Styling:** Outlined using the "Ghost Border" (15% `outline_variant`). 
- **Focus:** When active, the border shifts to `primary` with a 2px thickness. 

### Custom Component: The "Dhikr" Counter Widget
- A large, circular `surface_container_highest` element.
- Uses a `primary` color stroke that fills as progress increases.
- Center-aligned `display-md` typography for the count.

---

## 6. Do’s and Don’ts

### Do
- **Do** prioritize white space. If a layout feels "full," increase the spacing token by one level.
- **Do** use the `tertiary` (Gold) sparingly as a "divine spark"—only for active states or highlighted spiritual text.
- **Do** ensure all icons are "mirrored" for RTL (e.g., back arrows pointing right).

### Don't
- **Don't** use pure black (#000000). Always use `on_surface` (#1a1c1c) for text to maintain a soft, premium feel.
- **Don't** use standard Material 3 elevation (shadows level 1-5). Use Tonal Layering only.
- **Don't** mix Cairo with any other font. The strength of this system lies in its typographic purity.

---

## 7. Spacing & Grid
We utilize a **soft 4dp grid** scaled to the following tokens:
- **Tight (1.5):** 0.5rem (Inner card padding)
- **Standard (3):** 1rem (General gutter)
- **Wide (6):** 2rem (Section spacing)
- **Editorial (12):** 4rem (Hero top-margins)

*By following these guidelines, you will create an experience that feels less like a utility and more like a companion—a digital reflection of the peace found in prayer.*
