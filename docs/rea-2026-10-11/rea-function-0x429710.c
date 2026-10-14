
void __fastcall FUN_00429710(undefined4 *param_1)

{
  int iVar1;
  
  if ((undefined4 *)param_1[0x345] != (undefined4 *)0x0) {
    (*(code *)**(undefined4 **)param_1[0x345])(1);
  }
  iVar1 = 0;
  if (0 < (int)param_1[0x343]) {
    do {
      FUN_0043acc0(&DAT_004e1b00,(uint)*(ushort *)(param_1 + 0x339));
      iVar1 = iVar1 + 1;
    } while (iVar1 < (int)param_1[0x343]);
  }
  FUN_004851ae((LPVOID)param_1[1]);
  param_1[1] = 0;
  if ((LPVOID)param_1[0x337] != (LPVOID)0x0) {
    FUN_004851ae((LPVOID)param_1[0x337]);
  }
  *param_1 = 0;
  return;
}

