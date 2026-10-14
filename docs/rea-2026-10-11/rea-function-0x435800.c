
undefined4 __thiscall FUN_00435740(void *this,int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  
  if (*(int *)((int)this + 0x3c) != 2) {
    iVar1 = FUN_0042bb50(*(int *)(*(int *)((int)this + 0xc) + 0x78));
    if (param_1 == 2) {
      return 1;
    }
    if (param_1 == 3) {
      return 1;
    }
    if (param_1 == 4) {
      if (iVar1 == 0) {
        return 0;
      }
    }
    else {
      if (param_1 == 5) {
        return 1;
      }
      if (param_1 == 6) {
        if (iVar1 == 0) {
          return 0;
        }
        iVar2 = FUN_00435620((int)this);
        if (*(int *)(iVar1 + 0x34) == iVar2) {
          return 0;
        }
        if (*(int *)(iVar1 + 0x30) == 0) {
          return 1;
        }
        iVar2 = FUN_00432d00(6,param_2);
        if (*(int *)(*(int *)(iVar1 + 0x30) + 0x34) <= iVar2) {
          return 1;
        }
        return 0;
      }
      if (param_1 != 7) {
        if (param_1 == 8) {
          return 1;
        }
        if (param_1 != 9) {
          return 1;
        }
        iVar1 = FUN_00436230(this,3);
        if (iVar1 != 0) {
          return 1;
        }
        return 0;
      }
      if (iVar1 == 0) {
        return 0;
      }
    }
    if (*(int *)(iVar1 + 0x30) != 0) {
      return 1;
    }
  }
  return 0;
}

