"""Draw the placed macro and its center from the SKY130 HD cell GDS, before routing."""
import os
import subprocess
from pathlib import Path

import klayout.db as db
import klayout.lay as lay
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
work = Path('build/chip-render')
work.mkdir(parents=True, exist_ok=True)
report = subprocess.run(['openroad', '-exit', '/dev/stdin'], text=True, check=True,
                        stdout=subprocess.PIPE, input='''
read_db build/corner-optimized.odb
set b [ord::get_db_block]
set box [$b getDieArea]
puts "PLACEMENT [$b getName] [llength [$b getInsts]] [$b getDbUnitsPerMicron] [$box xMin] [$box yMin] [$box xMax] [$box yMax]"
write_def build/chip-render/eeg_challenge.def
''').stdout
name, count, units, *bounds = next(s.split()[1:] for s in report.splitlines() if s.startswith('PLACEMENT '))
die = db.DBox(*(int(x) / int(units) for x in bounds))
pdk = Path(os.environ.get('PDK_ROOT', '/foss/pdks')) / 'sky130A'
hd = pdk / 'libs.ref/sky130_fd_sc_hd'
tech = pdk / 'libs.tech/klayout/tech'
opts = db.LoadLayoutOptions()
cfg = opts.lefdef_config
cfg.lef_files = [str(hd / 'techlef/sky130_fd_sc_hd__nom.tlef'), str(hd / 'lef/sky130_fd_sc_hd.lef')]
cfg.macro_layout_files = [str(hd / 'gds/sky130_fd_sc_hd.gds')]
cfg.macro_resolution_mode = 2  # Always use GDS masters, never LEF abstract rectangles.
cfg.map_file = str(tech / 'sky130A.map')
opts.lefdef_config = cfg
layout = db.Layout()
layout.read(str(work / 'eeg_challenge.def'), opts)
top = layout.cell(name)
instances = list(top.each_inst())
masters = {inst.cell_index for inst in instances}
poly = layout.find_layer(66, 20)
if len(instances) != int(count) or poly is None or any(layout.cell(i).shapes(poly).is_empty() for i in masters):
    raise ValueError('Placement or transistor gate geometry missing from GDS import')

view = lay.LayoutView()
view.show_layout(layout, True)
view.active_cellview().cell = top
view.max_hier()
view.load_layer_props(str(tech / 'sky130A.lyp'))
view.set_config('background-color', '#ffffff')
view.set_config('grid-visible', 'false')
view.set_config('text-visible', 'false')
# Show the cell artwork, not name labels, LEF obstructions or cell boundary markers.
visible = {(64, 20), (65, 20), (65, 44), (66, 20), (66, 44), (67, 20), (67, 44), (68, 20)}
for layer in view.each_layer():
    if layer.source_layer >= 0:
        layer.visible = (layer.source_layer, layer.source_datatype) in visible

n, gap = 1050, 48
c = die.center()
zoom = db.DBox(c.x - 16, c.y - 16, c.x + 16, c.y + 16)
sheet = Image.new('RGB', (2*n + gap, n + 84), 'white')
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype('DejaVuSans.ttf', 28)
for x, box, title, scale in [(0, die, 'Placed core and test wrapper', 100), (n+gap, zoom, 'Center detail', 5)]:
    path = work / ('macro.png' if x == 0 else 'detail.png')
    view.save_image_with_options(str(path), n, n, 0, 2, 0, box, False)
    with Image.open(path) as field:
        sheet.paste(field.convert('RGB'), (x, 0))
    draw.rectangle((x, 0, x+n-1, n-1), outline='#b3b9bd', width=2)
    draw.text((x, n+20), title, fill='#162a32', font=font)
    right, y = x+n-4, n+38
    length = round(n*scale/box.width())
    draw.line((right-length, y, right, y), fill='#162a32', width=5)
    draw.text((right-length-16, y), f'{scale} µm', font=font, fill='#162a32', anchor='rm')
half = n * zoom.width() / die.width() / 2
draw.rectangle((n/2-half,n/2-half,n/2+half,n/2+half), outline='#242424', width=3)
sheet.save('proposal/chip-render.png', optimize=True)
print(f'{name}: {count} placed instances, {len(masters)} GDS masters; {die.width():.2f} × {die.height():.2f} µm; center detail 32 × 32 µm')
