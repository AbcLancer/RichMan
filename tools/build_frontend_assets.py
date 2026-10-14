"""Convert the original loose mainmenu TGA assets without changing their layout."""
from pathlib import Path
from PIL import Image
import argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', default=r'D:\Projects\reference\Rich6\mainmenu')
    args = parser.parse_args()
    root = Path(args.source)
    out = Path(__file__).resolve().parents[1] / 'game/assets/ui/frontend'
    count = 0
    for path in root.rglob('*'):
        if path.suffix.lower() != '.tga':
            continue
        image = Image.open(path).convert('RGBA')
        target = out / path.relative_to(root).with_suffix('.png')
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        count += 1
    print(f'Converted {count} original menu images')

if __name__ == '__main__':
    main()
