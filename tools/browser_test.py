"""Load the hosted web build in headless Chrome (SwiftShader WebGL2), capture console + screenshots.
Usage: browser_test.py <dir> <out_prefix> [w h] [--play] [--early] [--mobile] [--query=pack=mobile]
                       [--locale=ko-KR] [--throttle=Mbit/s] [--nosw] [--revisit] [--smoke]"""
import asyncio, sys, threading, http.server, functools, os, time
from playwright.async_api import async_playwright

d = sys.argv[1]
out = sys.argv[2]
W = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 1280
H = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 720
PLAY = "--play" in sys.argv
EARLY = "--early" in sys.argv
NOSW = "--nosw" in sys.argv
REVISIT = "--revisit" in sys.argv
SMOKE = "--smoke" in sys.argv
CARD_WAIT = float(next((a.split("=")[1] for a in sys.argv if a.startswith("--card-wait=")), "1.5"))  # s on the briefing card  # exit 1 on page errors, engine errors or missing milestones (CI)  # after the title screen, load the page again (service-worker cache)  # no service worker: its requests bypass the network throttle  # press start before the streamed content has arrived (wait card)
MOBILE = "--mobile" in sys.argv
QUERY = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--query=")), "")
LOCALE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--locale=")), "ko-KR")
THROTTLE = float(next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--throttle=")), "0"))  # Mbit/s, 0 = off
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
        if NOSW:
            kw["service_workers"] = "block"
        ctx = await b.new_context(**kw)
        pg = await ctx.new_page()
        if THROTTLE > 0:
            cdp = await ctx.new_cdp_session(pg)
            await cdp.send("Network.enable")
            await cdp.send("Network.emulateNetworkConditions", {"offline": False, "latency": 40,
                "downloadThroughput": THROTTLE * 1e6 / 8, "uploadThroughput": 5e6 / 8})
            print("network throttled to %.0f Mbit/s" % THROTTLE)
        pg.set_default_timeout(120000)
        logs = []
        pg.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
        marks = {}

        def on_mark(m):
            if "ERROR" in m.text or "Resumed" in m.text or m.type == "error":
                print("T+%.2fs !! %s" % (time.time() - t0, m.text[:300]))
            if "RB_MARK" in m.text or "[RB]" in m.text:
                print("T+%.2fs %s" % (time.time() - t0, m.text))
                if "RB_MARK" in m.text:
                    marks.setdefault(m.text.split()[1], time.time() - t0)
        pg.on("console", on_mark)

        async def wait_mark(name, limit=180):
            for _ in range(limit * 10):
                if name in marks:
                    return True
                await pg.wait_for_timeout(100)
            print("timeout waiting for", name)
            return False
        pg.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
        t0 = time.time()
        pg.on("requestfinished", lambda r: print("T+%.2fs got %s" % (time.time() - t0, r.url.split("/")[-1][:40])) if (".bin" in r.url or ".txt" in r.url or "index.js" in r.url) else None)
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
        await wait_mark("menu_first_frame")
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path=out + "_menu.png")
        if not EARLY:
            # the live diorama replaces the pre-rendered picture once the streamed content is in
            if await wait_mark("menu_world_built", 300):
                await pg.wait_for_timeout(3000)
                await pg.screenshot(path=out + "_menu3d.png")
        if REVISIT:
            print("SUMMARY first visit", {k: round(v, 1) for k, v in marks.items()})
            marks.clear()
            await pg.wait_for_timeout(3000)
            t0 = time.time()
            await pg.reload()
            await wait_mark("menu_first_frame")
            await wait_mark("menu_world_built", 120)
            await pg.wait_for_timeout(1500)
            await pg.screenshot(path=out + "_revisit.png")
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
            await pg.wait_for_timeout(int(CARD_WAIT * 1000))
            await pg.screenshot(path=out + "_card.png")
            t_click = time.time() - t0
            await pg.mouse.click(745, 530)
            if EARLY:
                await pg.wait_for_timeout(1500)
                await pg.screenshot(path=out + "_wait.png")
            await wait_mark("level_first_frame", 90)
            print("level ready %.1fs after pressing start" % (marks.get("level_first_frame", 0) - t_click))
            await pg.wait_for_timeout(4000)
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
            if "RB_MARK" not in l:
                print(l)
        print("SUMMARY", {k: round(v, 1) for k, v in marks.items()})
        await b.close()
        if SMOKE:
            need = ["menu_first_frame", "chunk_menu", "chunk_stage1", "chunk_towers", "chunk_world", "menu_world_built"]
            if PLAY:
                need.append("level_first_frame")
            bad = ["missing milestone " + n for n in need if n not in marks]
            for l in logs:
                if "GL Driver" in l:
                    continue
                if (l.startswith(("[error]", "[pageerror]")) or "SCRIPT ERROR" in l or "CHUNK MISS" in l
                        or "Cannot get class" in l or "Failed loading resource" in l):
                    bad.append(l[:200])
            if bad:
                print("SMOKE FAIL\n  " + "\n  ".join(bad[:30]))
                sys.exit(1)
            print("SMOKE OK")

asyncio.run(main())
