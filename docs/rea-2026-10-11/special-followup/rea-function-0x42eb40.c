
int __thiscall FUN_0042eb40(void *this,int param_1,int param_2,int param_3)

{
  int iVar1;
  int iVar2;
  int iVar3;
  void *this_00;
  int iVar4;
  int local_8;
  int local_4;
  
  iVar3 = 0;
  iVar2 = 0;
  local_8 = 0;
  local_4 = 0;
  if (0 < *(int *)((int)this + 0x28)) {
    do {
      iVar1 = *(int *)((int)this + 0x24);
      this_00 = (void *)(iVar1 + iVar3);
      iVar4 = 0;
      if (0 < *(int *)(iVar1 + 0x4c + iVar3) * *(int *)(iVar1 + 0x50 + iVar3)) {
        do {
          iVar2 = FUN_0042b1b0(this_00,iVar4);
          if ((((*(int *)(iVar2 + 0x34) == param_1) && (iVar1 = *(int *)(iVar2 + 0x30), iVar1 != 0))
              && (*(int *)(iVar1 + 0x38) == param_2)) &&
             ((*(int *)(iVar1 + 0x34) == param_3 && (*(int *)(iVar2 + 0x14) == iVar4)))) {
            local_8 = local_8 + 1;
          }
          iVar4 = iVar4 + 1;
          iVar2 = local_8;
        } while (iVar4 < *(int *)((int)this_00 + 0x4c) * *(int *)((int)this_00 + 0x50));
      }
      local_4 = local_4 + 1;
      iVar3 = iVar3 + 0x58;
    } while (local_4 < *(int *)((int)this + 0x28));
  }
  return iVar2;
}

