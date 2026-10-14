
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_0041d9e0(void *this,int param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  
  iVar3 = 0;
  if (0 < *(int *)((int)this + 0x4c) * *(int *)((int)this + 0x50)) {
    iVar2 = 0;
    do {
      iVar1 = *(int *)((int)this + 0x54) + iVar2;
      if ((*(byte *)(iVar1 + 0xc) & 2) != 0) {
        *(undefined4 *)(iVar1 + 0x28) = *(undefined4 *)(iVar1 + 0x2c);
        *(undefined4 *)(iVar1 + 0x24) = 0;
        *(undefined4 *)(iVar1 + 0x20) = 0;
        *(undefined4 *)(iVar1 + 0x1c) = 0;
      }
      iVar3 = iVar3 + 1;
      iVar2 = iVar2 + 0x40;
    } while (iVar3 < *(int *)((int)this + 0x4c) * *(int *)((int)this + 0x50));
  }
  iVar3 = 0;
  if (0 < *(int *)((int)this + 0x4c) * *(int *)((int)this + 0x50)) {
    iVar2 = 0;
    do {
      iVar1 = *(int *)(*(int *)((int)this + 0x54) + 0x30 + iVar2);
      if ((iVar1 != 0) && (*(int *)(*(int *)((int)this + 0x54) + iVar2 + 0x14) == iVar3)) {
        FUN_0041d800(this,iVar3,iVar1);
      }
      iVar3 = iVar3 + 1;
      iVar2 = iVar2 + 0x40;
    } while (iVar3 < *(int *)((int)this + 0x4c) * *(int *)((int)this + 0x50));
  }
  if (param_1 != 0) {
    _DAT_004e3810 = 1;
    return;
  }
  _DAT_004e3b78 = 1;
  return;
}

