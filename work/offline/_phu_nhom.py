# -*- coding: utf-8 -*-
"""_phu_nhom.py — nhom cac ham server con THIEU theo module, de chon lam truoc."""
import collections
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import _phu_rpc as P

CHI_CHOI_DON = {
    'G_ArenaLogic', 'G_GuildWarLogic', 'G_ScoreCompetitivePlayProtocol',
    'G_ServerInfoProtocol', 'G_EndlessChapterLogic', 'G_EpicChapterLogic',
    'G_GuildLogic', 'G_GuildApplyLogic', 'G_COGProtocol', 'G_COGCityDefendMission',
    'G_RankLogic', 'G_WorldBossLogic', 'G_StateWarLogic', 'G_CrossWarLogic',
}


def main():
    goi = P.quet_goi(P.cay.ASSETS)
    da = P.dang_ky()
    #[[ SO KHOA PHAI LA TEN TRAN. Tu 30/10 cac handler moi dang ky bang khoa co
    #   tien to obj (`R:on("G_X.ClientY")`) — do la khoa DUNG cua router (router
    #   thu "obj.func" truoc roi moi toi ten tro), nhung so voi ten client gui
    #   (`CallServer(..., "ClientY")`) thi phai lay phan SAU dau cham cuoi.
    #   Truoc 31/10 cho nay so thang `da` nen moi khoa co obj deu bi bao THIEU
    #   (dung ho bay "hoi sai doi tuong" da ghi trong memory). ]]
    da_tran = {ten.split('.')[-1] for ten in da}
    thieu = collections.OrderedDict()
    for s, m, f, rel, ln in goi:
        if f not in da_tran:
            thieu.setdefault(m or '(toan cuc)', set()).add(f)
    print('%-42s %4s  %s' % ('module', 'so', 'vi du'))
    for m in sorted(thieu, key=lambda k: -len(thieu[k])):
        ds = sorted(thieu[m])
        nhan = '' if m not in CHI_CHOI_DON else '   [che do phu]'
        print('%-42s %4d  %s%s' % (m, len(ds), ', '.join(ds[:5]), nhan))


if __name__ == '__main__':
    main()
