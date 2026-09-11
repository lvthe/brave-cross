"""Ghép tag đo được từ máy ảo vào các file bố cục.

    python emu_join.py                      # xem khớp được bao nhiêu
    python emu_join.py --ghi                # ghi trường "tag" vào layout_ref

Đầu vào là `tags_that.json` do `emu_tags.py` sinh ra: với mỗi màn, một cây
đường dẫn kiểu `lAchieveTemplate/4/1` (tên node gốc rồi lần lượt các tag)
kèm kích thước và vị trí mà engine báo về.

Ghép bằng VỊ TRÍ chứ không bằng kích thước. Cocos đặt vị trí theo điểm neo,
tương đối với cha, và con số đó giống hệt trong file. Kích thước thì không:
với sprite, engine trả về cỡ ảnh THẬT sau khi nạp, còn file ghi cỡ lúc thiết
kế — ví dụ một icon trạng thái file ghi 107x87 mà engine báo 118x88.

Có node không bao giờ lấy được tag: `getChildByTag` chỉ trả về node ĐẦU TIÊN
mang tag đó, nên anh em trùng tag thì những cái sau bị khuất. Đó là giới hạn
của chính engine, không phải của phép đo — và cũng có nghĩa mã gốc không bao
giờ với tới chúng bằng tag.
"""
import argparse
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
LAYOUT = HERE.parent.parent / 'bravecross-game' / 'layout_ref'
DO = HERE / 'tags_that.json'
GAN = 0.51          # sai lech vi tri cho phep (px)


def ten(n):
    return n.get('name') or n.get('cls') or ''


def tim_theo_ten(node, muon):
    if ten(node) == muon:
        return node
    for c in node.get('children', []):
        r = tim_theo_ten(c, muon)
        if r is not None:
            return r
    return None


def chon_con(cha, o, da_dung):
    """Con nào của `cha` ứng với node engine báo ở vị trí o."""
    ung = [c for c in cha.get('children', [])
           if abs(c['x'] - o['x']) <= GAN and abs(c['y'] - o['y']) <= GAN]
    if not ung:
        return None
    # Uu tien cai chua bi gan, va cai khop ca kich thuoc.
    chua = [c for c in ung if id(c) not in da_dung]
    for bo in (chua, ung):
        khop = [c for c in bo
                if abs(c['w'] - o['w']) <= 1.0 and abs(c['h'] - o['h']) <= 1.0]
        if khop:
            return khop[0]
    return chua[0] if chua else ung[0]


def ghep_mot_man(doc, cay):
    """Trả về (số khớp, số không khớp). Gắn thẳng 'tag' vào node của doc."""
    goc = {}
    for r in doc.get('roots', []):
        pass
    da_dung = set()
    khop = truot = 0
    # Sap theo do sau de cha luon duoc giai truoc con.
    for duong in sorted(cay, key=lambda d: d.count('/')):
        o = cay[duong]
        phan = duong.split('/')
        if len(phan) == 1:                       # node goc, tra theo ten
            nut = None
            for r in doc.get('roots', []):
                nut = tim_theo_ten(r, phan[0])
                if nut is not None:
                    break
            if nut is not None:
                goc[duong] = nut
            continue
        cha = goc.get('/'.join(phan[:-1]))
        if cha is None:
            truot += 1
            continue
        con = chon_con(cha, o, da_dung)
        if con is None:
            truot += 1
            continue
        con['tag'] = int(phan[-1])
        da_dung.add(id(con))
        goc[duong] = con
        khop += 1
    return khop, truot


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--ghi', action='store_true', help='ghi vao layout_ref')
    ap.add_argument('--do', default=str(DO))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    p = pathlib.Path(a.do)
    if not p.exists():
        raise SystemExit('chua co %s — chay emu_tags.py truoc' % p)
    duoc = json.loads(p.read_text('utf-8'))
    nodes = duoc.get('nodes', {})
    print('co du lieu do cho %d man' % len(nodes))

    tong_khop = tong_truot = tong_man = 0
    for man, cay in sorted(nodes.items()):
        f = LAYOUT / (man.replace('.xgg', '') + '.json')
        if not f.exists():
            continue
        doc = json.loads(f.read_text('utf-8'))
        khop, truot = ghep_mot_man(doc, cay)
        tong_khop += khop
        tong_truot += truot
        tong_man += 1
        if a.ghi:
            f.write_text(json.dumps(doc, ensure_ascii=False), encoding='utf-8')
    print('%d man: %d node gan duoc tag, %d khong khop duoc'
          % (tong_man, tong_khop, tong_truot))
    if a.ghi:
        print('da ghi vao layout_ref')
    else:
        print('(chay lai voi --ghi de ghi vao layout_ref)')


if __name__ == '__main__':
    main()
