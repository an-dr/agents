# Diagrams in a page

What a diagram shows, its type, and how much it may hold belong to `an-dr-convention-diagram`. In an HTML report:

- Each diagram is a `<pre class="mermaid">` block of Mermaid source; `<`, `>`, `&` escaped as HTML entities; labels with punctuation quoted.
- Page CSS never styles `label`, `node`, `edgeLabel`, `cluster`, `actor`, `note`; it leaks into the SVG and clips text. Page classes have distinct names.
- A wide diagram sits in its own `overflow-x: auto` container so the page never scrolls sideways.
