
void __fastcall FUN_004299c0(int param_1)

{
  int *this;
  int *piVar1;
  int iVar2;
  float *pfVar3;
  int local_4;
  
  this = *(int **)(DAT_0050d0d4 + 0xd0);
  iVar2 = 0;
  local_4 = 0;
  if (0 < *(int *)(param_1 + 0xce0)) {
    do {
      pfVar3 = (float *)(*(int *)(param_1 + 0xcdc) + iVar2);
      if (*(int *)(*(int *)(param_1 + 0xcdc) + 0x44 + iVar2) != 0) {
        FUN_00404ea0(this);
        FUN_00404f30(this,pfVar3);
        piVar1 = (int *)FUN_0043abb0(&DAT_004e1b00,(uint)*(ushort *)(pfVar3 + 0x10));
        (**(code **)(*piVar1 + 8))(0);
        FUN_00404ed0((int)this);
        FUN_0043acc0(&DAT_004e1b00,(uint)*(ushort *)(pfVar3 + 0x10));
        pfVar3[0x11] = 0.0;
      }
      local_4 = local_4 + 1;
      iVar2 = iVar2 + 0x48;
    } while (local_4 < *(int *)(param_1 + 0xce0));
  }
  (**(code **)(**(int **)(param_1 + 0xd14) + 8))(0);
  return;
}

