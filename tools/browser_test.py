"""Load the hosted web build in headless Chrome (SwiftShader WebGL2), capture console + screenshots.
Usage: browser_test.py <dir> <out_prefix> [w h] [--play]"""
import asyncio, sys, threading, http.server, functools, os, time
from playwright.async_api import async_playwright

d = sys.argv[1]
out = sys.argv[2]
W = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 1280
H = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 720
PLAY = "--play" in sys.argv
MOBILE = "--mobile" in sys.argv


class Q(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


def serve():
    h = functools.partial(Q, directory=d)
    http.server.ThreadingHTTPServer(("127.0.0.1", 8765), h).serve_forever()


threading.Thread(target=serve, daemon=True).start()


async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path="/usr/bin/google-chrome", headless=True,
                                    args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"])
        ctx = await b.new_context(viewport={"width": W, "height": H}, device_scale_factor=(3 if MOBILE else 1), has_touch=MOBILE, is_mobile=MOBILE)
        pg = await ctx.new_page()
        logs = []
        pg.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
        pg.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
        t0 = time.time()
        await pg.goto("http://127.0.0.1:8765/index.html")
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path=out + "_loading.png")
        # wait for engine to start (status overlay removed)
        for i in range(120):
            gone = await pg.evaluate("document.getElementById('status') === null")
            if gone:
                break
            await pg.wait_for_timeout(1000)
        print("engine started after %.1fs" % (time.time() - t0))
        await pg.wait_for_timeout(9000)
        await pg.screenshot(path=out + "_menu.png")
        if MOBILE:
            await pg.touchscreen.tap(170, 250)
            await pg.wait_for_timeout(2500)
            await pg.screenshot(path=out + "_select.png")
            await pg.touchscreen.tap(107, 282)
            await pg.wait_for_timeout(12000)
            await pg.screenshot(path=out + "_level.png")
            await pg.touchscreen.tap(W * 0.55, H * 0.5)
            await pg.wait_for_timeout(1500)
            await pg.screenshot(path=out + "_tap.png")
        if PLAY:
            # press "게임 시작" (bottom-left), then the first level card's button
            await pg.mouse.click(236, 445)
            await pg.wait_for_timeout(2500)
            await pg.screenshot(path=out + "_select.png")
            await pg.mouse.click(148, 510)
            await pg.wait_for_timeout(12000)
            await pg.screenshot(path=out + "_level.png")
            # tap the hero portrait, then the ground (hero move); then press pause
            await pg.mouse.click(62, H - 120 + 8 + 48)
            await pg.wait_for_timeout(800)
            await pg.mouse.click(W / 2 + 120, H / 2 + 40)
            await pg.wait_for_timeout(2500)
            await pg.screenshot(path=out + "_hero.png")
            await pg.mouse.click(W - 14 - 33, 12 + 33)
            await pg.wait_for_timeout(1500)
            await pg.screenshot(path=out + "_pause.png")
        for l in logs[-40:]:
            print(l)
        await b.close()

asyncio.run(main())
