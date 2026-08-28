"""dopaz のアプリアイコンを生成する。

lib/widgets/dopaz_logo.dart のマークと同じ形・同じ配色をPNGとして書き出す。
形は「右上だけ角を残した円」、色は lib/theme.dart のライトテーマの
cyanLight -> cyan の斜めグラデーション。

配色や形を変えたら次を実行して各サイズを作り直す:
    python tool/generate_icons.py
"""

import struct
import zlib
from pathlib import Path

# lib/theme.dart の TopazColors.light と揃えること
CYAN_LIGHT = (0x8F, 0xEA, 0xF2)
CYAN = (0x00, 0xB8, 0xD4)
WHITE = (0xFF, 0xFF, 0xFF)

SAMPLES = 4  # 1辺あたりのスーパーサンプリング数 (輪郭のアンチエイリアス用)


def render(size, mark_ratio=1.0, background=None):
    """マークを描いたRGBAのバイト列を返す。

    mark_ratio: キャンバスに対するマークの一辺の比率。
    background: 背景色。None なら透過。
    """
    mark = size * mark_ratio
    offset = (size - mark) / 2
    radius = mark / 2
    # 右上以外の角を丸めた形は「内接円 + 右上の四分割」と同じになる
    cx = cy = offset + radius

    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            r_sum = g_sum = b_sum = a_sum = 0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    px = x + (sx + 0.5) / SAMPLES
                    py = y + (sy + 0.5) / SAMPLES
                    if px >= cx and py <= cy:
                        inside = offset <= px <= offset + mark and py >= offset
                    else:
                        inside = (px - cx) ** 2 + (py - cy) ** 2 <= radius**2
                    if inside:
                        # 左上から右下への線形グラデーション
                        t = ((px - offset) + (py - offset)) / (2 * mark)
                        t = min(1.0, max(0.0, t))
                        r_sum += CYAN_LIGHT[0] + (CYAN[0] - CYAN_LIGHT[0]) * t
                        g_sum += CYAN_LIGHT[1] + (CYAN[1] - CYAN_LIGHT[1]) * t
                        b_sum += CYAN_LIGHT[2] + (CYAN[2] - CYAN_LIGHT[2]) * t
                        a_sum += 1

            total = SAMPLES * SAMPLES
            coverage = a_sum / total
            if coverage == 0:
                fr, fg, fb = background or (0, 0, 0)
                alpha = 255 if background else 0
            else:
                fr, fg, fb = r_sum / a_sum, g_sum / a_sum, b_sum / a_sum
                if background:
                    # 背景色の上に乗せる
                    fr = background[0] + (fr - background[0]) * coverage
                    fg = background[1] + (fg - background[1]) * coverage
                    fb = background[2] + (fb - background[2]) * coverage
                    alpha = 255
                else:
                    alpha = round(coverage * 255)
            row += bytes((round(fr), round(fg), round(fb), alpha))
        rows.append(bytes(row))
    return rows


def write_png(path, rows, size):
    raw = b"".join(b"\x00" + row for row in rows)  # 各行の先頭はフィルタ種別

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(
            ">I", zlib.crc32(body) & 0xFFFFFFFF
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)
    print(f"{path} ({size}x{size}, {len(png):,} bytes)")


def main():
    root = Path(__file__).resolve().parent.parent

    # Web: タブのファビコンとPWAアイコンは透過、マークをほぼ全面に
    write_png(root / "web/favicon.png", render(32, 0.94), 32)
    for size in (192, 512):
        write_png(
            root / f"web/icons/Icon-{size}.png", render(size, 0.9), size
        )
    # maskable は端を切られるので、白地に小さめのマークを置く
    for size in (192, 512):
        write_png(
            root / f"web/icons/Icon-maskable-{size}.png",
            render(size, 0.6, background=WHITE),
            size,
        )

    # Android: ランチャーアイコンは不透明な正方形にする
    for density, size in (
        ("mdpi", 48),
        ("hdpi", 72),
        ("xhdpi", 96),
        ("xxhdpi", 144),
        ("xxxhdpi", 192),
    ):
        write_png(
            root / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png",
            render(size, 0.66, background=WHITE),
            size,
        )


if __name__ == "__main__":
    main()
