
longlong __thiscall FUN_0042bf90(void *this,int param_1)

{
  int iVar1;
  byte *pbVar2;
  undefined4 extraout_EDX;
  undefined4 uVar3;
  undefined4 extraout_EDX_00;
  byte *pbVar4;
  byte *pbVar5;
  int iVar6;
  longlong lVar7;
  byte local_100 [256];
  
  iVar1 = FUN_0042b1b0(*(void **)((int)this + 0x28),*(int *)((int)this + 0x2c));
  if (*(int *)(iVar1 + 0x30) != 0) {
    iVar6 = 0;
    pbVar2 = (byte *)FUN_0042ed40(*(void **)((int)this + 0x3c),(int)local_100,
                                  *(int *)(*(int *)(iVar1 + 0x30) + 0x38),*(int *)(iVar1 + 0x34));
    uVar3 = extraout_EDX;
    if (0 < (int)pbVar2) {
      pbVar5 = local_100;
      pbVar4 = pbVar2;
      do {
        lVar7 = FUN_0042b9c0(*(void **)(*(int *)pbVar5 + 0x28),*(int *)(*(int *)pbVar5 + 0x2c));
        uVar3 = (undefined4)((ulonglong)lVar7 >> 0x20);
        iVar6 = iVar6 + (int)lVar7;
        pbVar5 = pbVar5 + 4;
        pbVar4 = pbVar4 + -1;
      } while (pbVar4 != (byte *)0x0);
    }
    if ((1 < (int)pbVar2) && (param_1 != 0)) {
      FUN_0043cb00(DAT_004fe7ac,0x3f4,pbVar2,local_100);
      uVar3 = extraout_EDX_00;
    }
    return CONCAT44(uVar3,iVar6);
  }
  lVar7 = FUN_0042b9c0(*(void **)((int)this + 0x28),*(int *)((int)this + 0x2c));
  return lVar7;
}

