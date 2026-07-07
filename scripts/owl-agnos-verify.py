#!/usr/bin/env python3
# owl-agnos-verify — prove owl's sit-backed VCS change-marker gutter WORKS on the
# real agnos kernel in QEMU (owl 1.4.3 + sit 1.3.2's repo-root-relative FS layer).
# Boots gnoboot+OVMF over an NVMe ext2 rootfs holding /bin/owl + /bin/agnsh + a
# seeded .sit repo at /f (file `a`: line-2 modified, line-4 added vs HEAD), drives
# agnsh over HMP sendkey, runs `run /bin/owl /f/a`, and polls serial for the gutter.
#
# On agnos owl has no cwd, so vcs_compute_markers walks up from /f/a to /f/.sit,
# tells sit the root (sit_set_repo_root), and diffs the repo-relative path "a".
# PASS = owl renders the file AND emits the gutter markers `~` (VCS_MARK_MOD, line 2)
#        and `+` (VCS_MARK_ADD, line 4) — the fixture text contains neither, so their
#        presence dispositively proves sit read the repo via absolute paths on agnos.
#
# Prereqs: agnos/scripts/build.sh (kernel) + stage-agnsh.sh; owl/build/owl-agnos;
#          host sit/build/sit (builds the fixture). Modeled on iam-agnos-verify.py.
import socket, subprocess, sys, time, os

OWL   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))          # .../owl
REPOS = os.path.dirname(OWL)                                                 # .../Repos
AGNOS_ROOT = os.path.join(REPOS, "agnos")
GNOBOOT = os.environ.get("GNOBOOT_ROOT", os.path.join(REPOS, "gnoboot")) + "/build/BOOTX64.EFI"
AGNOS   = os.path.join(AGNOS_ROOT, "build/agnos")
ROOTFS  = os.path.join(AGNOS_ROOT, "build/rootfs")
OWLBIN  = os.path.join(OWL, "build/owl-agnos")
SITBIN  = os.path.join(REPOS, "sit/build/sit")
WORK    = os.path.join(OWL, "build/owl-agnos-verify")
SEED    = os.path.join(WORK, "seed")
FIX     = os.path.join(WORK, "fixture")
IMG     = os.path.join(WORK, "agnos-owl.img")
SER     = os.path.join(WORK, "serial-owl.log")
MON     = "/tmp/agnos-owl.sock"
PART_OFFSET = 33 * 1048576
PART_BLOCKS = (67 * 1048576) // 4096
FEAT = os.environ.get("EXT2_SMOKE_FEATURES", "^resize_inode,^dir_index,^metadata_csum,^64bit,^uninit_bg")

def need(*paths):
    for p in paths:
        if not os.path.exists(p):
            print("FAIL: missing", p); sys.exit(1)
need(GNOBOOT, AGNOS, OWLBIN, SITBIN, os.path.join(ROOTFS, "bin/agnsh"))

OVMF_CODE = OVMF_VARS = None
for c in ("/usr/share/edk2/x64/OVMF_CODE.4m.fd","/usr/share/edk2/x64/OVMF_CODE.fd","/usr/share/OVMF/OVMF_CODE.fd","/usr/share/OVMF/OVMF_CODE_4M.fd"):
    if os.path.exists(c): OVMF_CODE = c; break
for c in ("/usr/share/edk2/x64/OVMF_VARS.4m.fd","/usr/share/edk2/x64/OVMF_VARS.fd","/usr/share/OVMF/OVMF_VARS.fd","/usr/share/OVMF/OVMF_VARS_4M.fd"):
    if os.path.exists(c): OVMF_VARS = c; break
if not OVMF_CODE or not OVMF_VARS: print("FAIL: OVMF not found"); sys.exit(1)

def sh(cmd, quiet=True):
    r = subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if r.returncode != 0: print("FAIL step:", cmd, "\n", r.stderr.decode("latin1")[:400]); sys.exit(1)

subprocess.run(["rm","-rf",WORK]); os.makedirs(WORK, exist_ok=True)

# --- 1. build the fixture .sit repo on the host (file `a`: commit, then edit) ---
os.makedirs(FIX)
open(os.path.join(FIX,"a"),"w").write("line one\nline two\nline three\n")
sh(f"cd {FIX} && {SITBIN} init && {SITBIN} add a && {SITBIN} commit -m initial")
open(os.path.join(FIX,"a"),"w").write("line one\nline two CHANGED\nline three\nline four ADDED\n")

# --- 2. assemble the seed rootfs: agnsh + owl + the fixture at /f ---
subprocess.run(["cp","-a",ROOTFS,SEED])
subprocess.run(["cp",OWLBIN,os.path.join(SEED,"bin/owl")])
subprocess.run(["cp","-a",FIX,os.path.join(SEED,"f")])

# --- 3. GPT + ESP(gnoboot+kernel) + ext2 rootfs (seeded) ---
sh(f"dd if=/dev/zero of={IMG} bs=1M count=128 status=none")
sh(f"parted -s {IMG} mklabel gpt mkpart ESP fat32 1MiB 33MiB set 1 esp on mkpart agnos-fs ext2 33MiB 100MiB")
sh(f"sgdisk -t 2:8300 {IMG} >/dev/null")
sh(f"mformat -i {IMG}@@1048576 -F"); sh(f"mmd -i {IMG}@@1048576 ::EFI ::EFI/BOOT ::boot")
sh(f"mcopy -i {IMG}@@1048576 {GNOBOOT} ::EFI/BOOT/BOOTX64.EFI"); sh(f"mcopy -i {IMG}@@1048576 {AGNOS} ::boot/agnos")
sh(f"mkfs.ext2 -F -q -L AGNOS-OWL -b 4096 -m 0 -O {FEAT} -d {SEED} -E offset={PART_OFFSET} {IMG} {PART_BLOCKS}")
subprocess.run(["cp",OVMF_VARS,os.path.join(WORK,"vars.fd")]); subprocess.run(["chmod","+w",os.path.join(WORK,"vars.fd")])
open(SER,"w").close()
try: os.unlink(MON)
except FileNotFoundError: pass
print("built owl-agnos-verify image:", IMG)

qemu = subprocess.Popen([
    "qemu-system-x86_64","-machine","q35","-m","512M","-enable-kvm","-cpu","host",
    "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
    "-drive", f"if=pflash,format=raw,file={WORK}/vars.fd",
    "-drive", f"file={IMG},format=raw,if=none,id=disk0",
    "-device","nvme,drive=disk0,serial=AGNOS-OWL",
    "-device","qemu-xhci,id=xhci","-device","usb-kbd,bus=xhci.0",
    "-serial", f"file:{SER}","-display","none","-no-reboot",
    "-monitor", f"unix:{MON},server,nowait",
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def p(*a): print(*a, flush=True)
rc = 1
try:
    s = None
    for _ in range(60):
        try: s = socket.socket(socket.AF_UNIX); s.connect(MON); break
        except OSError: time.sleep(0.2)
    if s is None: p("FAIL: no monitor"); sys.exit(1)
    s.settimeout(1.0)
    def drain():
        try:
            while True: s.recv(65536)
        except OSError: pass
    def ser():
        try: return open(SER,"rb").read().decode("latin1")
        except OSError: return ""
    km = {' ':'spc','\n':'ret','-':'minus','.':'dot','/':'slash','_':'shift-minus'}
    def key_for(ch):
        if ch in km: return km[ch]
        if ch.isupper(): return "shift-"+ch.lower()
        return ch

    ok = False
    for _ in range(480):
        if "agnoshi" in ser(): ok = True; break
        time.sleep(0.25)
    p("agnsh banner seen:", ok)
    if not ok: p("FAIL: no agnsh banner"); sys.exit(1)

    # Type `run /bin/owl /f/a` reliably: prime a fresh prompt, type char-by-char,
    # verify the echo shows the tail "/f/a", retry the whole line on a dropped key.
    CMD = "run /bin/owl /f/a"
    def type_cmd():
        for _attempt in range(6):
            s.sendall(b"sendkey ret\n"); time.sleep(0.7); drain()
            base = len(ser())
            for ch in CMD:
                s.sendall(("sendkey "+key_for(ch)+"\n").encode()); time.sleep(0.12); drain()
            time.sleep(0.6)
            echoed = ser()[base:].split("[ASSIST] >")[-1]
            if "/f/a" in echoed and "owl" in echoed:
                return True
            for _ in range(30):
                s.sendall(b"sendkey backspace\n"); time.sleep(0.04)
            drain()
        return False
    if not type_cmd():
        p("FAIL: could not type the owl command cleanly over sendkey (6 tries)"); s.sendall(b"quit\n"); sys.exit(1)
    m = len(ser())
    s.sendall(b"sendkey ret\n"); time.sleep(1.0)   # commit -> run /bin/owl (2.4 MB ELF off ext2)
    deadline = time.time() + 90
    seg = ""
    while time.time() < deadline:
        seg = ser()[m:]
        if ("line four ADDED" in seg) and ("~" in seg) and ("+" in seg): break
        time.sleep(0.5)
    p("=========== owl output on agnos ==========="); p(seg if seg.strip() else "(empty / wedged)"); p("===========================================")

    rendered = "line two CHANGED" in seg and "line four ADDED" in seg   # owl rendered the file
    mark_mod = "~" in seg                                               # VCS_MARK_MOD gutter (line 2)
    mark_add = "+" in seg                                               # VCS_MARK_ADD gutter (line 4)
    p("owl rendered the file (content on serial):", rendered)
    p("gutter MOD marker '~' present (line 2):", mark_mod)
    p("gutter ADD marker '+' present (line 4):", mark_add)
    if rendered and mark_mod and mark_add:
        p("owl-agnos-verify: PASS — owl's VCS gutter works on agnos: found the repo by walking up,")
        p("  read the diff via sit's absolute-path (repo-root) FS layer, rendered ~ and + markers.")
        rc = 0
    else:
        p("owl-agnos-verify: FAIL")
    s.sendall(b"quit\n"); time.sleep(0.2)
finally:
    qemu.terminate()
    try: qemu.wait(timeout=3)
    except subprocess.TimeoutExpired: qemu.kill()
sys.exit(rc)
