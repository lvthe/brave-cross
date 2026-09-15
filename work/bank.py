# -*- coding: utf-8 -*-
"""Boc am thanh ra khoi file .bank cua FMOD Studio, ghi thanh .ogg.

    python bank.py --json                       # kiem ke moi bank
    python bank.py --json --out bank_ref.json
    python bank.py --all --out ../../bravecross-game/assets_ref/audio
    python bank.py --bank Archer --out /tmp/thu

Vi sao phai tu boc: trong ca cay du an KHONG co mot file am thanh thuong nao
(ogg/mp3/wav/m4a/aac/caf/flac/mid/xm/it/mod — 0 hit), va tren may khong co
ffmpeg / vgmstream / pyfmodex. Am thanh cua ban goc nam het trong 361 file
`.bank`, va chung la FMOD Studio chu khong phai FSB tran.

Ba tang, do het chu khong suy:

1. VO CHUA. Bank = `RIFF` + `FEV `, di tung chunk tu 12. Chunk `SND ` nam CUOI
   va `SND+8+size == len(file)` o moi bank. Blob FSB5 nam trong ruot `SND `,
   nhung truoc no la mot doan dem 0 DAI THAY DOI (do duoc: 0, 2, 4, 6, 8, 10,
   12, 16, 20, 22, 24, 28, 30 byte), nen phai quet tim `FSB5` chu khong an
   cung kich thuoc header.

2. FSB5. Header 0x3c byte (ban 1): 0x00 magic, 0x04 version, 0x08 so subsound,
   0x0c co khoi mau, 0x10 co bang ten, 0x14 co khoi du lieu, 0x18 codec (moi
   bank o day la 0xF = Vorbis FMOD), 0x20 co. Moi mau mot u64 LE `sample_mode`:
   bit 63..34 so mau, bit 33..8 `((m>>7)&0x07FFFFFF)<<5` = offset trong khoi du
   lieu, bit 7..6 kenh (0->1, 1->2, 2->6, 3->8), bit 5..1 chi so tan so trong
   RATES, bit 0 = con khoi phu. Khoi phu la chuoi u32 `type=(x>>25)&0x7F`,
   `size=(x>>1)&0xFFFFFF`, `continue=x&1`; type 0x0B = "Vorbis setup ID and
   seek table", vay payload = `setup_id` u32 roi `table_size` u32.

   Bang ten KHONG phai cac chuoi noi nhau: no la `nsub` u32 offset, roi cac
   chuoi nam DUNG tai offset do. Doc bang `split('\\x00')` la sai — lan dau lam
   the va sinh ra ten rac kieu `Archer__\\x18`.

3. KHOI SETUP khong nam trong bank. Vorbis giai ma duoc thi can goi type 0x05
   (codebook), ma FSB5 chi tham chieu no bang `setup_id`. Nhung chinh
   `libfmod.so` cua game mang nguyen van 32 khoi `05 "vorbis"` — chung la
   khoi setup chuan (bo doc o day bam sat libvorbis nen bit framing cuoi cung
   phai bang 1; 32/32 dat). Ba id ma bank dung da nhan dien bang cach doi chieu
   do dai + sai khac byte nho nhat voi mot chi muc doc lap, va CHON BAN CUA
   LIBFMOD.SO (du lieu cua chinh game). Hai khoi lech 2 byte so voi chi muc —
   bon truong 4 bit doi gia tri 12 -> 15; ca hai ban deu doc duoc tron ven.

   Vi tri ghi bang (offset, do dai) chu KHONG ghi byte: `chon_kenh()` doc lai
   tu `libfmod.so` roi tu kiem bang chinh bo doc — libfmod doi thi no bao loi
   ngay, chu khong im lang xuat rac.

   Tim lai bang: `python vorbis_probe.py vn/apk/lib/armeabi-v7a/libfmod.so`.

4. SO KENH: truong `channels` cua FSB5 KHONG phai so kenh cua dong Vorbis. Do
   bang chinh trinh giai ma cua Godot (libvorbis) tren 18 file ghep tu 6
   subsound, moi subsound ghep o ba cach khai 1/2/6 kenh — xem `chon_kenh()`.
   Tom tat: 56/1498 subsound phai DOI so kenh so voi FSB5 ghi moi doc duoc.
"""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIBFMOD = os.path.join(HERE, 'vn', 'apk', 'lib', 'armeabi-v7a', 'libfmod.so')
BANKS = os.path.join(HERE, 'vn', 'apk', 'assets', 'banks')

RATES = [4000, 8000, 11000, 11025, 16000, 22050, 24000, 32000, 44100, 48000, 96000]
KENH = {0: 1, 1: 2, 2: 6, 3: 8}

# setup_id -> (offset trong libfmod.so, do dai goi setup)
SETUP_AT = {
    0x84d3ac87: (1039812, 3189),
    0x38aa59ce: (1035416, 3832),
    0xc55efa16: (1018984, 3547),
}

# vgmstream (vorbis_custom_utils_fsb.c) co dinh hai co khoi nay cho MOI setup
# cua FSB5: vorbis_get_blocksize_exp(2048) va (256). Do la ly do mot setup
# dung chung duoc cho ca 1 kenh lan 6 kenh.
KHOI_NGAN, KHOI_DAI = 256, 2048

# Chunk 0x0B cua FSB5 — vgmstream fsb5.c:645 (extradata_offset = extraflag_offset + 0x04).
PHU_SETUP = 0x0B


# --------------------------------------------------------------- doc khoi setup

def ov_ilog(v):
    return v.bit_length()


class BR:
    """Doc bit LSB-truoc, dung nhu libvorbis."""

    def __init__(self, b, pos):
        self.b = b
        self.p = pos
        self.bit = 0

    def read(self, n):
        v = 0
        for i in range(n):
            v |= ((self.b[self.p] >> self.bit) & 1) << i
            self.bit += 1
            if self.bit == 8:
                self.bit = 0
                self.p += 1
        return v

    def align(self):
        if self.bit:
            self.bit = 0
            self.p += 1
        return self.p


def quantvals_1(ent, dim):
    """_book_maptype1_quantvals cua libvorbis."""
    if dim == 0:
        return 0
    if dim == 1:
        return ent
    vals = int(ent ** (1.0 / dim))
    while True:
        acc = vals ** dim
        acc1 = (vals + 1) ** dim
        if acc <= ent < acc1:
            return vals
        vals += 1 if acc < ent else -1


def doc_setup(b, pos, kenh=2):
    """Tra (do_dai_byte, so_codebook, [blockflag tung mode]).

    Bam sat libvorbis: codebook.c vorbis_staticbook_unpack, info.c
    _vorbis_unpack_books, floor0.c, floor1.c, res0.c, mapping0.c. Tung so bit
    mot. Nho vay bit framing cuoi cung (phai bang 1) la phep kiem THAT SU —
    lech mot bit o bat cu dau deu truot.
    """
    br = BR(b, pos)
    if br.read(8) != 5:
        raise ValueError('byte dau khong phai 5')
    if bytes(br.read(8) for _ in range(6)) != b'vorbis':
        raise ValueError('thieu magic vorbis')
    ncb = br.read(8) + 1
    for k in range(ncb):
        if br.read(24) != 0x564342:
            raise ValueError('codebook %d: sync sai' % k)
        dim = br.read(16)
        ent = br.read(24)
        if ov_ilog(dim) + ov_ilog(ent) > 24:
            raise ValueError('codebook %d: dim/entries qua lon' % k)
        if br.read(1):
            # Co thu tu: MOT do dai 5 bit, roi tung doan ov_ilog(con lai) bit.
            length = br.read(5) + 1
            i = 0
            while i < ent:
                num = br.read(ov_ilog(ent - i))
                if num > ent - i or length > 32:
                    raise ValueError('codebook %d: doan co thu tu sai' % k)
                i += num
                length += 1
        else:
            unused = br.read(1)
            for _ in range(ent):
                if unused:
                    if br.read(1):
                        br.read(5)
                else:
                    br.read(5)
        mt = br.read(4)
        if mt in (1, 2):
            br.read(32)
            br.read(32)
            qq = br.read(4) + 1
            br.read(1)
            n = quantvals_1(ent, dim) if mt == 1 else ent * dim
            for _ in range(n):
                br.read(qq)
        elif mt != 0:
            raise ValueError('codebook %d: maptype %d' % (k, mt))
    for _ in range(br.read(6) + 1):
        if br.read(16) >= 1:
            raise ValueError('time backend la')
    so_floor = br.read(6) + 1
    for _ in range(so_floor):
        ft = br.read(16)
        if ft == 0:
            br.read(8); br.read(16); br.read(16); br.read(6); br.read(8)
            for _ in range(br.read(4) + 1):
                br.read(8)
        elif ft == 1:
            parts = br.read(5)
            cls = [br.read(4) for _ in range(parts)]
            mx = max(cls) if cls else -1
            dims = []
            for _ in range(mx + 1):
                dims.append(br.read(3) + 1)
                subs = br.read(2)
                if subs:
                    br.read(8)
                for _ in range(1 << subs):
                    br.read(8)
            br.read(2)          # mult
            rangebits = br.read(4)
            for c in cls:
                for _ in range(dims[c]):
                    br.read(rangebits)
        else:
            raise ValueError('floor type %d' % ft)
    so_residue = br.read(6) + 1
    for _ in range(so_residue):
        if br.read(16) > 2:
            raise ValueError('residue type')
        br.read(24); br.read(24); br.read(24)
        parts = br.read(6) + 1
        br.read(8)
        acc = 0
        for _ in range(parts):
            casc = br.read(3)
            if br.read(1):
                casc |= br.read(5) << 3
            acc += bin(casc).count('1')
        for _ in range(acc):
            br.read(8)
    so_mapping = br.read(6) + 1
    for _ in range(so_mapping):
        if br.read(16) != 0:
            raise ValueError('mapping type')
        sub = 1
        if br.read(1):
            sub = br.read(4) + 1
        if br.read(1):
            # Do rong la ov_ilog(so_kenh - 1) — dung nhu mapping0.c:113. Nhung
            # libvorbis CON KIEM GIA TRI (mapping0.c:117-121): hai chi so phai
            # khac nhau va phai nho hon so kenh. Thieu phep kiem do thi mot
            # khoi setup SAI van di het duoc chi vi so bit tinh ra dung —
            # do la cai bay da lam Godot tra OV_EBADHEADER tren BGM_Lose.ogg.
            w = ov_ilog(kenh - 1)
            for _ in range(br.read(8) + 1):
                m = br.read(w)
                ag = br.read(w)
                if m == ag or m >= kenh or ag >= kenh:
                    raise ValueError('mapping: buoc coupling sai (m=%d a=%d, %d kenh)'
                                     % (m, ag, kenh))
        if br.read(2) != 0:
            raise ValueError('mapping: 2 bit danh rieng khac 0')
        if sub > 1:
            # mapping0.c:128-133: moi kenh mot chi so 4 bit, phai < so submap.
            for _ in range(kenh):
                if br.read(4) >= sub:
                    raise ValueError('mapping: chmux vuot so submap')
        for _ in range(sub):
            br.read(8)
            f = br.read(8)
            if f >= so_floor:
                raise ValueError('mapping: chi so floor %d >= %d' % (f, so_floor))
            r = br.read(8)
            if r >= so_residue:
                raise ValueError('mapping: chi so residue %d >= %d' % (r, so_residue))
    nmodes = br.read(6) + 1
    flags = []
    for _ in range(nmodes):
        flags.append(br.read(1))
        br.read(16); br.read(16)
        if br.read(8) >= so_mapping:
            raise ValueError('mode: chi so mapping vuot so mapping')
    if br.read(1) != 1:
        raise ValueError('bit framing khac 1')
    return br.align() - pos, ncb, flags


_cache_setup = {}


def chon_kenh(sid, kenh_fsb):
    """Tra (bytes goi setup, {mode: co khoi}, so_kenh_dung, lech).

    Doc khoi setup tu chinh libfmod.so. Do dai da doi chieu DOC LAP voi chi muc
    `vcb_list` cua vgmstream (vcb.h): 0x84d3ac87 -> 0xc75 = 3189,
    0xc55efa16 -> 0xddb = 3547, 0x38aa59ce -> 0xef8 = 3832. Ba so khop tuyet doi.

    SO KENH: truong `channels` cua FSB5 KHONG phai so kenh cua dong Vorbis.
    Do bang chinh trinh giai ma cua Godot (libvorbis) tren 18 file ghep tu 6
    subsound, moi subsound ghep o ba cach khai 1/2/6 kenh:

      * setup 0x84d3ac87 (Archer, UI): nap duoc o CA BA cach khai, va
        `get_length()` ra DUNG so_mau/rate o ca ba (1,702 s / 0,249 s / 0,662 s).
        Vay khoi setup nay khong phu thuoc so kenh — dung so nao cung duoc.
      * setup 0x38aa59ce (BGM): CHI nap duoc khi khai 2 kenh (42,667 s va
        43,102 s, dung bang so_mau/rate). Khai 1 hoac 6 deu
        'Error parsing header packet 2: -133' = OV_EBADHEADER.

    Va so byte tren mau cua hai ban cung bai cho thay truong do la CAU HINH LOA
    chu khong phai so kenh: BGM_Battle_Normal (FSB5 ghi 1) 628.305 byte /
    2.048.000 mau, BGM_Battle_Normal02 (FSB5 ghi 6) 601.874 byte / 2.068.897
    mau — khai 2 kenh cho ca hai thi ra 0,153 va 0,145 byte/mau, gan nhu bang
    nhau. Neu "6" la 6 kenh that thi ban do phai nang gap ba.

    Nen: uu tien so kenh FSB5 ghi, nhung neu khoi setup khong doc duoc o so do
    thi tim so kenh khac lam bo doc chay het dung do dai da ghi. `lech` la True
    khi phai doi — do la cho DUNG SO lieu cua ban goc, khong phai sua cho vua.
    """
    if sid in _cache_setup:
        goi, dung, lech, fl = _cache_setup[sid]
        return goi, _khoi(fl), dung, lech
    if sid not in SETUP_AT:
        raise KeyError('setup id la: 0x%08x' % sid)
    if not os.path.isfile(LIBFMOD):
        raise IOError('khong thay %s' % LIBFMOD)
    off, dai = SETUP_AT[sid]
    with open(LIBFMOD, 'rb') as f:
        f.seek(off)
        goi = f.read(dai)
    thu = [kenh_fsb] + [x for x in range(1, 9) if x != kenh_fsb]
    dung = None
    fl = None
    for k in thu:
        try:
            n, _ncb, f_k = doc_setup(goi, 0, k)
        except ValueError:
            continue
        if n == dai:
            dung, fl = k, f_k
            break
    if dung is None:
        raise ValueError('setup 0x%08x: khong so kenh nao doc het %d byte'
                         % (sid, dai))
    lech = (dung != kenh_fsb)
    _cache_setup[sid] = (goi, dung, lech, fl)
    return goi, _khoi(fl), dung, lech


def _khoi(flags):
    """Mode co blockflag 0 dung khoi ngan, 1 dung khoi dai.

    FSB5 khong luu co khoi; vgmstream co dinh 256/2048 cho moi setup cua no
    (vorbis_custom_utils_fsb.c), va libvorbis tra co khoi bang
    `blocksizes[blockflag]` (vorbis_packet_blocksize).
    """
    return {i: (KHOI_DAI if fl else KHOI_NGAN) for i, fl in enumerate(flags)}


# ------------------------------------------------------------------ ghep .ogg

_TBL_CRC = []
for _i in range(256):
    _r = _i << 24
    for _ in range(8):
        _r = (((_r << 1) ^ 0x04C11DB7) & 0xFFFFFFFF if _r & 0x80000000
              else (_r << 1) & 0xFFFFFFFF)
    _TBL_CRC.append(_r)


def crc32_ogg(b):
    """CRC cua Ogg: khong phan xa, da thuc 0x04C11DB7, init 0, xorout 0.

    KHAC zlib.crc32 — dung zlib thi moi trang deu sai CRC va trinh giai ma
    lang le bo qua trang.
    """
    c = 0
    for x in b:
        c = ((c << 8) & 0xFFFFFFFF) ^ _TBL_CRC[((c >> 24) & 0xFF) ^ x]
    return c


def _ilog_exp(n):
    e = 0
    while (1 << e) < n:
        e += 1
    if (1 << e) != n:
        raise ValueError('co khoi %d khong phai luy thua 2' % n)
    return e


def _trang(goi, granule, serial, seq, htype):
    """Mot trang Ogg. Lacing: 255 byte moi doan, doan cuoi < 255."""
    segs = bytearray()
    body = bytearray()
    for p in goi:
        n = len(p)
        while n >= 255:
            segs.append(255)
            n -= 255
        segs.append(n)
        body += p
    if len(segs) > 255:
        raise ValueError('%d doan lacing, qua 255' % len(segs))
    head = bytearray(b'OggS\x00')
    head.append(htype)
    head += struct.pack('<q', granule)
    head += struct.pack('<I', serial)
    head += struct.pack('<I', seq)
    head += b'\x00\x00\x00\x00'
    head.append(len(segs))
    head += segs
    head += body
    struct.pack_into('<I', head, 22, crc32_ogg(bytes(head)))
    return bytes(head)


def _hd_nhan_dang(kenh, rate, khoi_ngan, khoi_dai, bitrate):
    return (b'\x01vorbis' + struct.pack('<I', 0) + bytes([kenh])
            + struct.pack('<I', rate)
            + struct.pack('<i', 0) + struct.pack('<i', bitrate) + struct.pack('<i', 0)
            + bytes([_ilog_exp(khoi_ngan) | (_ilog_exp(khoi_dai) << 4)])
            + b'\x01')


def _hd_chu_thich(vendor=b'fmod'):
    # 0 binh luan. Ten bai nam o ten FILE, khong nhet vao day: ten bank co the
    # chua byte khong phai UTF-8 va nhet bua thi trinh giai ma tu choi ca file.
    return (b'\x03vorbis' + struct.pack('<I', len(vendor)) + vendor
            + struct.pack('<I', 0) + b'\x01')


def ghep_ogg(goi_setup, khoi, kenh, rate, cac_goi, tong_mau):
    """Ghep cac goi Vorbis cua mot subsound thanh bytes cua file .ogg.

    goi_setup : khoi type 0x05 nguyen van tu libfmod.so
    khoi      : {chi so mode: co khoi}
    cac_goi   : danh sach goi am thanh, moi goi da la bytes cua than no
    tong_mau  : so mau FSB5 bao -> dat lam granule trang CUOI, de trinh giai
                ma cat dung phan dem cuoi cua Vorbis
    """
    serial = 0x46534235
    tong_byte = sum(len(p) for p in cac_goi)
    giay = tong_mau / float(rate) if rate else 1.0
    bitrate = int(tong_byte * 8 / giay) if giay > 0 else 0
    nho, lon = min(khoi.values()), max(khoi.values())

    out = bytearray()
    out += _trang([_hd_nhan_dang(kenh, rate, nho, lon, bitrate)], 0, serial, 0, 2)
    out += _trang([_hd_chu_thich(), goi_setup], 0, serial, 1, 0)

    so_mode = len(khoi)
    mat_na = (1 << max(1, ov_ilog(so_mode - 1))) - 1
    seq = 2
    gran = 0
    truoc = None
    buf = []
    segs = 0
    tong = len(cac_goi)
    for i, p in enumerate(cac_goi):
        mode = (p[0] >> 1) & mat_na
        if mode not in khoi:
            raise ValueError('goi %d: mode %d khong co trong setup' % (i, mode))
        b = khoi[mode]
        if truoc is not None:
            gran += (truoc + b) // 4
        truoc = b
        buf.append(p)
        segs += len(p) // 255 + 1
        cuoi = (i == tong - 1)
        if segs >= 200 or cuoi:
            out += _trang(buf, tong_mau if cuoi else gran, serial, seq, 0)
            seq += 1
            buf = []
            segs = 0
    return bytes(out)


# ------------------------------------------------------------------ doc .bank

def mo_bank(path):
    """Boc mot file .bank -> dict(subs=..., dat=...) hoac None neu khong phai FSB5."""
    with open(path, 'rb') as f:
        b = f.read()
    if b[:4] != b'RIFF':
        return None
    p = 12
    fsb = None
    while p + 8 <= len(b):
        cid = b[p:p + 4]
        sz, = struct.unpack_from('<I', b, p + 4)
        if cid == b'SND ':
            ruot = b[p + 8:p + 8 + sz]
            i = ruot.find(b'FSB5')
            if i < 0:
                return None
            f = p + 8 + i
            if struct.unpack_from('<I', b, f + 4)[0] != 1:
                return None
            fsb = f
            break
        p += 8 + sz + (sz & 1)
    if fsb is None:
        return None

    d = b[fsb:]
    _ver, nsub, shsize, ntsize, dsize, codec = struct.unpack_from('<6I', d, 4)
    if nsub == 0:
        return None
    hdr = d[0x3c:0x3c + shsize]
    nt = d[0x3c + shsize:0x3c + shsize + ntsize]
    dat = d[0x3c + shsize + ntsize:]

    # Bang ten: nsub u32 offset, roi chuoi o DUNG offset do. Khong split.
    ten = []
    for k in range(nsub):
        if 4 * k + 4 > len(nt):
            ten.append('sub%d' % k)
            continue
        o, = struct.unpack_from('<I', nt, 4 * k)
        e = nt.find(b'\x00', o) if 0 <= o < len(nt) else -1
        if e < 0:
            ten.append('sub%d' % k)
        else:
            ten.append(nt[o:e].decode('utf-8', 'replace'))

    off = 0
    subs = []
    for k in range(nsub):
        if off + 8 > len(hdr):
            return None
        m, = struct.unpack_from('<Q', hdr, off)
        off += 8
        s = dict(
            ten=ten[k],
            mau=(m >> 34) & 0x3FFFFFFF,
            doff=((m >> 7) & 0x07FFFFFF) << 5,
            kenh=KENH.get((m >> 6) & 3, 0),
            rate=RATES[(m >> 1) & 0xF] if ((m >> 1) & 0xF) < len(RATES) else 0,
            sid=None,
        )
        con = m & 1
        while con:
            if off + 4 > len(hdr):
                return None
            x, = struct.unpack_from('<I', hdr, off)
            off += 4
            t = (x >> 25) & 0x7F
            s_sz = (x >> 1) & 0xFFFFFF
            con = x & 1
            pl = hdr[off:off + s_sz]
            off += s_sz
            if t == PHU_SETUP and len(pl) >= 8:
                s['sid'], = struct.unpack_from('<I', pl, 0)
        subs.append(s)

    # Do dai moi luong = offset cua luong ke tiep, luong cuoi = het khoi du lieu.
    moc = sorted(set(x['doff'] for x in subs))
    for x in subs:
        i = moc.index(x['doff'])
        x['end'] = moc[i + 1] if i + 1 < len(moc) else dsize

    return dict(path=path, codec=codec, subs=subs, dat=dat, dsize=dsize)


def cac_goi(dat, s):
    """Boc mot luong thanh cac goi: [u16 LE do dai][than].

    0 va 0xFFFF la ket thuc / phan dem cuoi (vgmstream
    vorbis_custom_parse_packet_fsb). Moi goi trong luong deu la goi AM THANH —
    bit 0 cua byte dau bang 0 o ca 1498 subsound, tuc khong co goi header nao
    duoc luu chung.
    """
    cur = s['doff']
    out = []
    while cur + 2 <= s['end']:
        n, = struct.unpack_from('<H', dat, cur)
        if n in (0, 0xFFFF) or cur + 2 + n > s['end']:
            break
        out.append(dat[cur + 2:cur + 2 + n])
        cur += 2 + n
    return out


def tach(path, kiem_tat_ca=True):
    """Tra danh sach (subsound, bytes .ogg). Nem loi ra ngoai neu hong."""
    r = mo_bank(path)
    if r is None:
        raise ValueError('khong phai bank FSB5 doc duoc')
    if r['codec'] != 0xF:
        raise ValueError('codec 0x%x khong phai Vorbis (0xF)' % r['codec'])
    base = os.path.basename(path)
    if base.lower().endswith('.bank'):
        base = base[:-5]
    ra = []
    for s in r['subs']:
        if s['sid'] is None:
            raise ValueError('%s: subsound khong co chunk setup' % s['ten'])
        pk = cac_goi(r['dat'], s)
        if not pk:
            raise ValueError('%s: khong boc duoc goi nao' % s['ten'])
        if kiem_tat_ca:
            for i, p in enumerate(pk):
                if p[0] & 1:
                    raise ValueError('%s: goi %d co bit 0 bang 1 (goi header?)'
                                     % (s['ten'], i))
        goi, khoi, kenh_dung, lech = chon_kenh(s['sid'], s['kenh'])
        ogg = ghep_ogg(goi, khoi, kenh_dung, s['rate'], pk, s['mau'])
        ra.append((s, base, ogg, len(pk), kenh_dung, lech))
    return r, ra


# ------------------------------------------------------------------------ CLI

def duong_bank():
    if not os.path.isdir(BANKS):
        raise IOError('khong thay %s' % BANKS)
    return sorted(os.path.join(BANKS, f) for f in os.listdir(BANKS)
                  if f.lower().endswith('.bank'))


def ten_file(bank_ten, sub_ten):
    """Ten file .ogg cua mot subsound: `<bank>__<ten>.ogg`.

    Doi `/` va KHOANG TRANG thanh `_`: ten trong bank co ca hai
    (`Impact_Catapult_Light_ 02`). De nguyen thi duong dan `res://` co khoang
    trang — khong hong ngay, nhung la cho de vuong ve sau, ma bo di thi khong
    mat thong tin vi ten goc van nam trong bank_ref.json.
    """
    return '%s__%s.ogg' % (bank_ten, sub_ten.replace('/', '_').replace(' ', '_'))


def _gdignore(out):
    """Dat `.gdignore` vao thu muc xuat, de Godot KHONG quet no.

    Do duoc: tha 29 file .ogg vao `assets_ref/audio` lam Godot quet lai ca cay
    du an va chay qua 5 phut chua xong (tien trinh an 60 giay CPU roi van
    dung o buoc nap). `.gdignore` cat han buoc quet do.

    Khong mat gi: `AudioStreamOggVorbis.load_from_file()` doc thang file tren
    dia, khong di qua he thong nap tai nguyen — duong dan `res://...` van dung
    ke ca khi thu muc bi bo qua. Do la duong ta dung de phat am thanh.
    """
    p = os.path.join(out, '.gdignore')
    if not os.path.exists(p):
        with open(p, 'w', encoding='ascii') as f:
            f.write('# sinh boi brave-cross/work/bank.py - xem _gdignore()\n')


def main():
    import argparse
    import json
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', help='thu muc ghi .ogg, hoac file .json khi --json')
    ap.add_argument('--json', action='store_true', help='chi kiem ke, khong ghi .ogg')
    ap.add_argument('--all', action='store_true', help='quet het moi bank')
    ap.add_argument('--bank', action='append', default=[],
                    help='chi lam bank co ten nay (lap lai duoc)')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    paths = duong_bank()
    if a.bank:
        muon = set(x.lower() for x in a.bank)
        paths = [p for p in paths
                 if os.path.basename(p)[:-5].lower() in muon]
    if not a.all and not a.bank and not a.json:
        ap.error('chon --json hoac --all hoac --bank <ten>')

    kiem_ke = []
    hong = []
    tong_sub = 0
    lech_kenh = 0
    for path in paths:
        base = os.path.basename(path)[:-5]
        try:
            r, ra = tach(path)
        except Exception as e:
            hong.append((base, str(e)))
            continue
        for s, _b, ogg, n_goi, kenh_dung, lech in ra:
            ten_file_ = ten_file(base, s['ten'])
            kiem_ke.append(dict(bank=base, ten=s['ten'], kenh=kenh_dung,
                                kenh_fsb=s['kenh'], lech_kenh=lech,
                                rate=s['rate'], mau=s['mau'],
                                sid='%08x' % s['sid'], goi=n_goi,
                                giay=s['mau'] / float(s['rate']) if s['rate'] else 0.0,
                                file=ten_file_, ogg=len(ogg)))
            tong_sub += 1
            if lech:
                lech_kenh += 1
            if a.out and not a.json:
                os.makedirs(a.out, exist_ok=True)
                _gdignore(a.out)
                with open(os.path.join(a.out, ten_file_), 'wb') as f:
                    f.write(ogg)

    # Bang kiem ke ghi KEM thu muc am thanh, de bo kiem cua Godot
    # (tools/verify_am.gd) doc lai ma doi chieu do dai — khong phai chep tay
    # so mong doi vao mot file thu hai.
    if a.out and not a.json:
        with open(os.path.join(a.out, 'bank_ref.json'), 'w', encoding='utf-8') as f:
            json.dump(kiem_ke, f, ensure_ascii=False, indent=1)

    if a.json:
        if a.out and a.out.lower().endswith('.json'):
            with open(a.out, 'w', encoding='utf-8') as f:
                json.dump(kiem_ke, f, ensure_ascii=False, indent=1)
        else:
            json.dump(kiem_ke, sys.stdout, ensure_ascii=False, indent=1)
            print()
    else:
        for row in kiem_ke[:12]:
            print('  %-14s %-32s %dch %5dHz %8d mau %s -> %7d byte'
                  % (row['bank'], row['ten'], row['kenh'], row['rate'],
                     row['mau'], row['sid'], row['ogg']))
        if len(kiem_ke) > 12:
            print('  ... va %d subsound nua' % (len(kiem_ke) - 12))

    print('%d/%d bank doc duoc, %d subsound%s'
          % (len(paths) - len(hong), len(paths), tong_sub,
             (', ghi vao %s' % a.out) if (a.out and not a.json) else ''))
    if lech_kenh:
        print('%d subsound phai doi so kenh so voi FSB5 ghi — xem BANK.md'
              % lech_kenh)
    for base, loi in hong:
        print('  HONG %-24s %s' % (base, loi))
    return 1 if hong else 0


if __name__ == '__main__':
    sys.exit(main())
