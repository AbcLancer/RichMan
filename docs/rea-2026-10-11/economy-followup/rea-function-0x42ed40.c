
int __thiscall FUN_0042ed40(void *this,int param_1,int param_2,int param_3)

{
  void *this_00;
  int iVar1;
  int iVar2;
  int *piVar3;
  int iVar4;
  int *piVar5;
  int local_40c;
  int local_408;
  int local_400 [256];
  
  iVar4 = 0;
  local_40c = 0;
  local_408 = 0;
  iVar1 = 0;
  if (0 < *(int *)((int)this + 0x20)) {
    piVar5 = local_400;
    do {
      iVar1 = *(int *)(*(int *)((int)this + 0x24) + local_408 * 4);
      this_00 = *(void **)(iVar1 + 0x28);
      if (this_00 == (void *)0x0) {
        return local_40c;
      }
      iVar1 = FUN_0042b1b0(this_00,*(int *)(iVar1 + 0x2c));
      if (((*(int *)(iVar1 + 0x34) == param_3) && (*(int *)(iVar1 + 0x30) != 0)) &&
         (*(int *)(*(int *)(iVar1 + 0x30) + 0x38) == param_2)) {
        iVar2 = 0;
        if (0 < iVar4) {
          piVar3 = local_400;
          do {
            if (*(int *)(iVar1 + 0x14) == *piVar3) break;
            iVar2 = iVar2 + 1;
            piVar3 = piVar3 + 1;
          } while (iVar2 < iVar4);
        }
        if (iVar2 == iVar4) {
          *(undefined4 *)((param_1 - (int)local_400) + (int)piVar5) =
               *(undefined4 *)(*(int *)((int)this + 0x24) + local_408 * 4);
          local_40c = local_40c + 1;
          *piVar5 = *(int *)(iVar1 + 0x14);
          iVar4 = iVar4 + 1;
          piVar5 = piVar5 + 1;
        }
      }
      local_408 = local_408 + 1;
      iVar1 = local_40c;
    } while (local_408 < *(int *)((int)this + 0x20));
  }
  return iVar1;
}

