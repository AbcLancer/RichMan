
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __fastcall FUN_0044e0a0(int param_1)

{
  int *piVar1;
  char *pcVar2;
  int iVar3;
  
  FUN_0045a2e0(DAT_00500178);
  if (*(int *)(param_1 + 0xe8) != 0) {
    if (*(int *)(param_1 + 0x110) == 0) {
      iVar3 = 0x41;
    }
    else {
      _DAT_004fdb34 = *(undefined4 *)(param_1 + 0x114);
      iVar3 = 0x40;
      _DAT_004fdb24 = *(int *)(param_1 + 0x110);
    }
    piVar1 = (int *)FUN_0042a8a0(&DAT_005090b0,iVar3);
    pcVar2 = (char *)FUN_0042a940(piVar1,0x4fdb20);
    FUN_0042ae10(PTR_DAT_0049cf30,0,pcVar2,0xffffffff,iVar3);
    if (*(void **)(param_1 + 0x110) != (void *)0x0) {
      FUN_004366f0(*(void **)(param_1 + 0x110),10);
    }
  }
  return;
}

