"""Load the hosted web build in headless Chrome (SwiftShader WebGL2), capture console + screenshots.
Usage: browser_test.py <dir> <out_prefix> [w h] [--play] [--mobile] [--query=pack=mobile] [--locale=ko-KR]"""
import asyncio, sys, threading, http.server, functools, os, time
from playwright.async_api import async_playwright

d = sys.argv[1]
out = sys.argv[2]
W = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 1280
H = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 720
PLAY = "--play" in sys.argv
MOBILE = "--mobile" in sys.argv
QUERY = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--query=")), "")
LOCALE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--locale=")), "ko-KR")
UA_PHONE = ("Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/126.0.0.0 Mobile Safari/537.36")


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
        kw = dict(viewport={"width": W, "height": H}, device_scale_factor=(2 if MOBILE else 1), has_touch=MOBILE, is_mobile=MOBILE, locale=LOCALE)
        if MOBILE:
            kw["user_agent"] = UA_PHONE
        ctx = await b.new_context(**kw)
        pg = await ctx.new_page()
        pg.set_default_timeout(120000)
        logs = []
        pg.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
        pg.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
        t0 = time.time()
        await pg.goto("http://127.0.0.1:8765/index.html" + ("?" + QUERY if QUERY else ""))
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path=out + "_loading.png")
        # wait for engine to start (status overlay removed)
        for i in range(120):
            gone = await pg.evaluate("document.getElementById('status') === null")
            if gone:
                break
            await pg.wait_for_timeout(1000)
        print("engine started after %.1fs" % (time.time() - t0))
        info = await pg.evaluate("""async () => ({
            etc: !!document.createElement('canvas').getContext('webgl2').getExtension('WEBGL_compressed_texture_etc'),
            sw: navigator.serviceWorker ? (await navigator.serviceWorker.getRegistrations()).length : -1,
            manifest: !!document.querySelector('link[rel=manifest]'),
            build: typeof RB_BUILD === 'string' ? RB_BUILD : '' })""")
        print("browser:", info)
        await pg.wait_for_timeout(9000)
        await pg.screenshot(path=out + "_menu.png")
        if MOBILE:
            # phones use the compact 960x540 canvas (expanded to the screen aspect): map canvas -> CSS px
            k = H / 540.0
            await pg.touchscreen.tap(238 * k, 256 * k)          # 게임 시작
            await pg.wait_for_timeout(2500)
            await pg.screenshot(path=out + "_select.png")
            await pg.touchscreen.tap(351 * k, 350 * k)          # flag 1 on the world map
            await pg.wait_for_timeout(1500)
            await pg.screenshot(path=out + "_card.png")
            await pg.touchscreen.tap(687 * k, 418 * k)          # 출전
            await pg.wait_for_timeout(12000)
            await pg.screenshot(path=out + "_level.png")
            await pg.touchscreen.tap(W * 0.55, H * 0.5)
            await pg.wait_for_timeout(1500)
            await pg.screenshot(path=out + "_tap.png")
        if PLAY:
            # 게임 시작 -> world map flag 1 -> briefing card 출전
            await pg.mouse.click(238, 436)
            await pg.wait_for_timeout(2500)
            await pg.screenshot(path=out + "_select.png")
            await pg.mouse.click(384, 407)
            await pg.wait_for_timeout(1500)
            await pg.screenshot(path=out + "_card.png")
            await pg.mouse.click(745, 530)
            await pg.wait_for_timeout(12000)
            await pg.screenshot(path=out + "_level.png")
            # tap the hero portrait, then the ground (hero move); then press pause
            await pg.mouse.click(63, H - 128 + 2 + 49)
            await pg.wait_for_timeout(800)
            await pg.mouse.click(W / 2 + 120, H / 2 + 40)
            await pg.wait_for_timeout(2500)
            await pg.screenshot(path=out + "_hero.png")
            await pg.mouse.click(W - 14 - 32, 12 + 32)
            await pg.wait_for_timeout(1500)
            await pg.screenshot(path=out + "_pause.png")
        for l in logs[-40:]:
            print(l)
        await b.close()

asyncio.run(main())
