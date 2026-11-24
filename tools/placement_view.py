"""Render the OpenDB geometry stream from placement_view.tcl; no plotting dependencies."""

from pathlib import Path
import sys


def main():
    dbu, expected, dx0, dy0, dx1, dy1, cx0, cy0, cx1, cy1 = map(int, next(sys.stdin).split())
    dw, dh = dx1 - dx0, dy1 - dy0
    cw, ch = cx1 - cx0, cy1 - cy0
    n = 24
    areas = [[0] * n for _ in range(n)]
    # The detail is always centered on the row core, never chosen for its density.
    zoom_w, zoom_h = 60 * dbu, 18 * dbu
    zx, zy = (cx0 + cx1 - zoom_w) // 2, (cy0 + cy1 - zoom_h) // 2
    detail = []
    total = count = 0
    for count, line in enumerate(sys.stdin, 1):
        x0, y0, x1, y1 = map(int, line.split())
        if not (cx0 <= x0 < x1 <= cx1 and cy0 <= y0 < y1 <= cy1):
            raise ValueError(f'Instance {count} has an empty or out-of-core footprint')
        total += (x1 - x0) * (y1 - y0)
        if x0 < zx + zoom_w and x1 > zx and y0 < zy + zoom_h and y1 > zy:
            detail.append((x0, y0, x1, y1))
        # Multiply coordinates by n so bin edges and intersection areas stay exact.
        l, r = (x0 - cx0) * n, (x1 - cx0) * n
        b, t = (y0 - cy0) * n, (y1 - cy0) * n
        for j in range(b // ch, (t - 1) // ch + 1):
            h = min(t, (j + 1) * ch) - max(b, j * ch)
            for i in range(l // cw, (r - 1) // cw + 1):
                areas[j][i] += h * (min(r, (i + 1) * cw) - max(l, i * cw))
    if not count or count != expected:
        raise ValueError(f'Incomplete geometry stream: {count} of {expected} instances')

    inks = ['#edf3f2', '#c3dcd8', '#87b4ae', '#47877f', '#18574f']
    paths = [[] for _ in inks]
    for j, row in enumerate(areas):
        for i, area in enumerate(row):
            if area > cw * ch:
                raise ValueError('Cell area exceeds bin area')
            band = min(len(inks) - 1, len(inks) * area // (cw * ch))
            paths[band].append(f'M{i} {n - 1 - j}h1v1h-1z')
    parts = []
    emit = parts.append

    def rect(x, y, w, h, attrs):
        emit(f'<rect x="{x:.3f}" y="{y:.3f}" width="{w:.3f}" height="{h:.3f}" {attrs}/>')

    def text(x, y, label, size=16, attrs=''):
        emit(f'<text x="{x}" y="{y}" font-size="{size}" {attrs}>{label}</text>')

    emit('<svg xmlns="http://www.w3.org/2000/svg" width="800" height="428" viewBox="0 0 800 428" role="img" aria-labelledby="title desc">')
    emit('<title id="title">Legalized SKY130 HD standard-cell placement</title>')
    emit(f'<desc id="desc">Density of {count:,} placed cell footprints within the unassigned trial rectangle from corner-optimized.odb. Inset shows individual cells at the center. No clock tree or routes.</desc>')
    rect(0, 0, 800, 428, 'fill="white"')
    emit('<g font-family="DejaVu Sans,sans-serif" fill="#203b3a">')
    text(16, 29, 'Legalized placement', 23, 'font-weight="bold"')
    text(782, 27, 'SKY130 HD  /  PRE-ROUTE', 16, 'text-anchor="end"')
    emit('<path d="M16 41H784" stroke="#c5d3d0"/>')

    s = 290 / max(dw, dh)
    map_x = lambda x: 17 + (x - dx0) * s
    map_y = lambda y: 55 + (dy1 - y) * s
    rect(17, 55, dw * s, dh * s, 'fill="none" stroke="#203b3a" stroke-width="1.8"')
    emit(f'<g transform="translate({map_x(cx0):.4f} {map_y(cy1):.4f}) scale({cw*s/n:.5f} {ch*s/n:.5f})" shape-rendering="crispEdges">')
    for ink, commands in zip(inks, paths):
        emit(f'<path fill="{ink}" d="{"".join(commands)}"/>')
    emit('</g>')
    frame = 'fill="none" stroke="#8d4c24" stroke-width="1.8"'
    for attrs in ('fill="none" stroke="white" stroke-width="4"', frame):
        rect(map_x(zx), map_y(zy + zoom_h), zoom_w*s, zoom_h*s, attrs)
    bar = 100 * dbu * s
    emit(f'<path d="M17 356v6m0 -3h{bar:.3f}m0 -3v6" fill="none" stroke="#203b3a" stroke-width="2"/>')
    text(round(24 + bar), 365, '100 µm')
    text(16, 389, f'Trial: {dw/dbu:.2f} × {dh/dbu:.2f} µm')

    text(334, 71, 'Standard-cell coverage', 20, 'font-weight="bold"')
    text(334, 96, f'{count:,} cells  ·  {total/(dbu*1000)**2:.4f} mm²  ·  {100*total/(cw*ch):.1f}% of core')
    text(334, 124, f'Footprint area per bin ({n} × {n} bins over row core):')
    for i, ink in enumerate(inks):
        rect(338 + 76*i, 135, 76, 14, f'fill="{ink}"')
    for i in range(6):
        text(338 + 76*i, 168, f'{20*i}%', 14, 'text-anchor="middle"')
    text(334, 209, 'Center detail  ·  60 × 18 µm', 19, 'font-weight="bold"')
    z = 384 / zoom_w
    rect(334, 222, zoom_w*z, zoom_h*z, 'fill="white"')
    emit('<defs><clipPath id="window"><rect x="334" y="222" width="384" height="115.2"/></clipPath></defs>')
    emit('<g clip-path="url(#window)" fill="#78a59e" stroke="#2a534e" stroke-width="0.7">')
    for x0, y0, x1, y1 in sorted(detail):
        rect(334 + (x0-zx)*z, 222 + (zy+zoom_h-y1)*z, (x1-x0)*z, (y1-y0)*z, '')
    emit('</g>')
    rect(334, 222, zoom_w*z, zoom_h*z, frame)
    text(334, 363, 'Each outlined cell is one placed instance.')
    text(334, 387, 'White gaps are not occupied by cells.')
    emit('<path d="M16 399H784" stroke="#c5d3d0"/>')
    text(16, 420, 'Outer line: standalone trial rectangle. No approved slot, clock tree, routing or GDS.', 16)
    emit('</g></svg>')
    Path('proposal/placement.svg').write_text('\n'.join(parts) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
