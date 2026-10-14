
void __fastcall FUN_00429b90(int param_1)

{
  int iVar1;
  int *piVar2;
  int iVar3;
  int iVar4;
  
  iVar3 = 0;
  if (0 < *(int *)(param_1 + 0xce0)) {
    iVar4 = 0;
    do {
      iVar1 = iVar4 + *(int *)(param_1 + 0xcdc);
      if (*(int *)(iVar4 + 0x44 + *(int *)(param_1 + 0xcdc)) != 0) {
        piVar2 = (int *)FUN_0043abb0(&DAT_004e1b00,
                                     CONCAT22((short)((uint)iVar1 >> 0x10),
                                              *(undefined2 *)(iVar1 + 0x40)));
        (**(code **)(*piVar2 + 0xc))();
      }
      iVar3 = iVar3 + 1;
      iVar4 = iVar4 + 0x48;
    } while (iVar3 < *(int *)(param_1 + 0xce0));
  }
  return;
}

