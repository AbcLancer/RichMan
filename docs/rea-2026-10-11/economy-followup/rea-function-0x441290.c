
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00441170(void *this,double param_1)

{
  double dVar1;
  bool bVar2;
  int iVar3;
  undefined3 extraout_var;
  byte *pbVar4;
  int iVar5;
  int iVar6;
  int iVar7;
  
  iVar5 = 0;
  *(double *)((int)this + 0x20) = param_1 + *(double *)((int)this + 0x20);
  if (*(int *)((int)this + 0x30) != 0) {
    iVar6 = 0;
    if (0 < *(int *)((int)this + 8)) {
      do {
        iVar7 = iVar5 + *(int *)((int)this + 4);
        if ((*(int *)(iVar5 + 0x40 + *(int *)((int)this + 4)) != 0) && (*(int *)(iVar7 + 0x48) == 0)
           ) {
          iVar3 = FUN_0042e6e0(&DAT_004e3820,iVar7);
          *(int *)(iVar7 + 0x50) = iVar3;
        }
        iVar6 = iVar6 + 1;
        iVar5 = iVar5 + 0x3a8;
      } while (iVar6 < *(int *)((int)this + 8));
    }
    *(undefined4 *)((int)this + 0x30) = 0;
  }
  iVar5 = 0;
  dVar1 = param_1 + *(double *)((int)this + 0x10);
  *(double *)((int)this + 0x10) = dVar1;
  if (0.3 < dVar1) {
    FUN_0043cb00(DAT_004fe7ac,0x66,
                 (byte *)(*(int *)((int)this + 4) + *(int *)((int)this + 0x18) * 0x3a8),(byte *)0x0)
    ;
    iVar6 = *(int *)((int)this + 0x18) + 1;
    *(int *)((int)this + 0x18) = iVar6;
    if (iVar6 == *(int *)((int)this + 0xc)) {
      *(undefined4 *)((int)this + 0x18) = 0;
    }
    *(undefined4 *)((int)this + 0x10) = 0;
    *(undefined4 *)((int)this + 0x14) = 0;
  }
  if (0 < DAT_004f2a44) {
    bVar2 = FUN_00441350();
    if (CONCAT31(extraout_var,bVar2) != 0) {
      if (0 < *(int *)((int)this + 8)) {
        iVar6 = 0;
        do {
          if (*(int *)(iVar6 + 0x40 + *(int *)((int)this + 4)) != 0) {
            FUN_0043f350((void *)(iVar6 + *(int *)((int)this + 4)));
          }
          iVar5 = iVar5 + 1;
          iVar6 = iVar6 + 0x3a8;
        } while (iVar5 < *(int *)((int)this + 8));
      }
      FUN_0043cb00(DAT_004fe7ac,0x6a,(byte *)0x0,(byte *)0x0);
    }
    if (1 < DAT_004f2a44) {
      iVar5 = FUN_0041c2f0(0x4f2a38);
      if ((iVar5 == 1) && (0x48 < DAT_004f2a40)) {
        iVar5 = FUN_00441810(this,2,(void *)0x0);
        _DAT_004fdb24 = *(undefined4 *)(iVar5 + 0x2e0);
        FUN_0042ab30(&DAT_005090b0,0xd3,(int *)&DAT_004fdb20);
      }
      iVar5 = FUN_004418b0(this);
      pbVar4 = (byte *)(iVar5 / *(int *)((int)this + 0x28));
      if (9 < (int)pbVar4) {
        pbVar4 = (byte *)0x9;
      }
      iVar5 = FUN_0041a950(&DAT_004e3b28,3);
      if (iVar5 < (int)pbVar4) {
        FUN_0041aa80(&DAT_004e3b28,3,pbVar4);
        FUN_0043cb00(DAT_004fe7ac,0x226,(byte *)0x3,pbVar4);
      }
    }
    iVar5 = 0;
    if (0 < *(int *)((int)this + 8)) {
      iVar6 = 0;
      do {
        if (*(int *)(*(int *)((int)this + 4) + 0x40 + iVar6) != 0) {
          FUN_0043fe10(*(int *)((int)this + 4) + iVar6);
        }
        iVar5 = iVar5 + 1;
        iVar6 = iVar6 + 0x3a8;
      } while (iVar5 < *(int *)((int)this + 8));
    }
    if (0 < *(int *)((int)this + 0x2c)) {
      pbVar4 = (byte *)(*(int *)((int)this + 0x2c) + -1);
      *(byte **)((int)this + 0x2c) = pbVar4;
      FUN_0043cb00(DAT_004fe7ac,0x68,pbVar4,(byte *)0x0);
    }
  }
  return;
}

