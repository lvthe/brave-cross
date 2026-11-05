# -*- coding: utf-8 -*-
"""_con_lai.py — sinh `CON-LAI.md`: bản kiểm kê khoá RPC còn thiếu của lớp offline.

    python -I _con_lai.py

Chạy lại được sau mỗi lượt thêm handler. Nguồn số là `_phu_rpc.py` (quét cây client
CHỈ-ĐỌC), cộng bảng PHAN_LOAI bên dưới — bảng ấy là KẾT LUẬN ĐÃ ĐO của các lượt
trước, không phải suy đoán; mỗi mục ghi lý do và ngày đo.
"""
import collections
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import _phu_rpc as P

OUT = os.path.join(HERE, 'CON-LAI.md')

# module -> (nhóm lý do, ghi chú ĐO ĐƯỢC)
PHAN_LOAI = {
    'G_GuildLogic': ('nhieu nguoi', 'bang hoi: offline mot nguoi, phai viet moi mo hinh'),
    'G_FriendLogic': ('nhieu nguoi', 'ban be: offline khong co ai de ket ban'),
    'G_GuildWarLogic': ('nhieu nguoi', 'cong thanh: can bang hoi'),
    'G_GuildChapterLogic': ('nhieu nguoi', 'kenh chuong bang hoi'),
    'G_GuildCampLogic': ('nhieu nguoi', 'doanh trai bang hoi'),
    'G_GuildStoreLogic': ('nhieu nguoi', 'cua hang bang hoi; share KHONG co phan ket toan'),
    'G_COGProtocol': ('nhieu nguoi', 'COG: can thanh vien'),
    'G_COGCityDefendMission': ('nhieu nguoi', 'COG: nhiem vu giu thanh'),
    'G_ScoreCompetitivePlayProtocol': ('nhieu nguoi', 'dau truong diem: can nguoi choi khac'),
    'G_TournamentLogic': ('0 than ham', 'giai dau: 0 than ham trong 973 tep'),
    'G_WCSProtocol': ('0 than ham', 'giai dau the gioi: 0 than ham'),
    'G_RankLogic': ('du lieu toan server', '14 khoa da do la chet/thieu du lieu (Moc 57/59)'),
    'G_RechargeLogic': ('SDK chet', 'thanh toan: ClientDealPayment bi chu thich ca hai cho'),
    'G_ServerStateWarProtocol': ('nhieu nguoi', 'chien truong trang thai'),
    'G_ChapterLogic': ('thieu luat', '5 che do ai dac biet (DK/TGZZ/HJRQ/DJSJF/XZWC) chua chay'),
    'G_HeroLogic': ('0 than ham', 'canh/ky nang: 12 khoa 0 than trong share/ (do 30/10)'),
    'G_EquipmentLogic': ('0 than ham', 'trang bi doc quyen: 4 khoa 0 than'),
    'G_ItemLogic': ('0 than ham', 'BuyItem/Refine/SellRedundant: 0 than'),
    'G_ArenaLogic': ('nhieu nguoi', 'con lai chu yeu can doi thu that'),
    'G_GodSecret': ('da lam', 'ClientBuyGoods cua GodSecret: share 0 than'),
}


def main():
    goi = P.quet_goi(P.cay.ASSETS)
    da = P.dang_ky()
    da_tran = {ten.split('.')[-1] for ten in da}

    thieu = collections.OrderedDict()
    for s, m, f, rel, ln in goi:
        if f not in da_tran:
            thieu.setdefault(m or '(toan cuc)', set()).add(f)

    tong = sum(len(v) for v in thieu.values())
    dong = []
    dong.append('# CON-LAI — khoá RPC lớp offline CHƯA có handler\n')
    dong.append('Sinh tự động bằng `python -I _con_lai.py`. Đừng sửa tay.\n')
    dong.append('| | |')
    dong.append('|---|---|')
    ten_goi = set(f for _, _, f, _, _ in goi)
    co = len(da_tran & ten_goi)
    dong.append('| Tổng số TÊN hàm client gọi | **%d** |' % len(ten_goi))
    dong.append('| Có handler (theo tên hàm) | **%d** |' % co)
    dong.append('| **Còn thiếu (theo tên)** | **%d** |' % (len(ten_goi) - co))
    dong.append('| Còn thiếu (theo cặp module+tên) | **%d** |\n' % tong)

    nhom = collections.OrderedDict()
    for m, ds in thieu.items():
        loai = PHAN_LOAI.get(m, ('chua phan loai', ''))
        nhom.setdefault(loai[0], []).append((m, ds, loai[1]))

    for loai, ds_nhom in sorted(nhom.items(), key=lambda kv: -sum(len(x[1]) for x in kv[1])):
        n = sum(len(x[1]) for x in ds_nhom)
        dong.append('## %s — %d khoá\n' % (loai, n))
        dong.append('| module | số | ghi chú |')
        dong.append('|---|---:|---|')
        for m, ds, ghi in sorted(ds_nhom, key=lambda x: -len(x[1])):
            dong.append('| `%s` | %d | %s |' % (m, len(ds), ghi))
        dong.append('')

    dong.append('## Khoá lẻ (mỗi khoá phải phân tích riêng)\n')
    for m in ('(toan cuc)',):
        if m in thieu:
            dong.append('`%s` — %d khoá: %s\n' % (m, len(thieu[m]),
                                                 ', '.join(sorted(thieu[m]))))

    open(OUT, 'w', encoding='utf-8').write('\n'.join(dong))
    print('da ghi %s (%d khoa con thieu / %d)' % (OUT, tong, len(set((m, f) for _, m, f, _, _ in goi))))


if __name__ == '__main__':
    main()
