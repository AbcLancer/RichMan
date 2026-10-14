
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

undefined4 __thiscall FUN_0042b510(void *this,uint param_1,byte *param_2)

{
  undefined4 uVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  int iVar6;
  uint uVar7;
  int iVar8;
  
  iVar5 = FUN_0042b1b0(this,param_1);
  uVar1 = *(undefined4 *)(iVar5 + 0x34);
  _DAT_004e3b78 = 1;
  uVar7 = (uint)((int)this - DAT_004e3844) / 0x58;
  if (*(int *)(iVar5 + 0x30) == 0) {
    *(byte **)(iVar5 + 0x34) = param_2;
    FUN_0043cb00(DAT_004fe7ac,0xcd,(byte *)((uVar7 | 0x100) << 8 | param_1),param_2);
    return uVar1;
  }
  iVar2 = *(int *)(iVar5 + 0x14);
  iVar3 = *(int *)((int)this + 0x4c);
  param_1 = 0;
  iVar4 = *(int *)(*(int *)(iVar5 + 0x30) + 0x34);
  if (0 < iVar4) {
    do {
      iVar8 = 0;
      do {
        iVar6 = FUN_0042b1c0(this,iVar8 + iVar2 % iVar3,param_1 + iVar2 / iVar3);
        iVar8 = iVar8 + 1;
        *(byte **)(iVar6 + 0x34) = param_2;
      } while (iVar8 < iVar4);
      param_1 = param_1 + 1;
    } while ((int)param_1 < iVar4);
  }
  FUN_0043cb00(DAT_004fe7ac,0xcd,(byte *)((iVar4 << 8 | uVar7) << 8 | *(uint *)(iVar5 + 0x14)),
               param_2);
  return uVar1;
}

