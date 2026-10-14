
undefined4 __thiscall FUN_00436230(void *this,int param_1)

{
  int iVar1;
  
  if (*(int *)((int)this + 0x3c) == 2) {
    return 0;
  }
  if (*(int *)(*(int *)((int)this + 0xc) + 0x98) == 0) {
    return 0;
  }
  if (param_1 == 3) {
    if (*(int *)((int)this + 0x178) < DAT_0049e968) {
      return 0;
    }
    iVar1 = FUN_00435fe0(this,2);
    if (iVar1 != 0) {
      return 0;
    }
    iVar1 = 4;
  }
  else {
    if (param_1 != 5) {
      return 1;
    }
    iVar1 = FUN_00435fe0(this,2);
    if (iVar1 != 0) {
      return 0;
    }
    iVar1 = FUN_00435fe0(this,4);
    if (iVar1 != 0) {
      return 0;
    }
    iVar1 = 3;
  }
  iVar1 = FUN_00435fe0(this,iVar1);
  if (iVar1 != 0) {
    return 0;
  }
  return 1;
}

