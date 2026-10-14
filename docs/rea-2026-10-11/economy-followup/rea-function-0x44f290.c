
void __fastcall FUN_0044f290(int param_1)

{
  int iVar1;
  int iVar2;
  int *piVar3;
  int iVar4;
  
  iVar1 = *(int *)(&DAT_004e1c94 + DAT_004e2a84 * 0x1e0);
  piVar3 = (int *)(param_1 + 0x168);
  iVar4 = 4;
  do {
    if (*piVar3 != 0) {
      iVar2 = FUN_00433510(*piVar3,piVar3[-0x24]);
      if (iVar1 < iVar2) {
        FUN_00457ed0((void *)piVar3[-0x28],0);
      }
    }
    piVar3 = piVar3 + 1;
    iVar4 = iVar4 + -1;
  } while (iVar4 != 0);
  return;
}

