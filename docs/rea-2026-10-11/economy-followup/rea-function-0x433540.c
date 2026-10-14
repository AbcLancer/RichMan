
void __cdecl FUN_00433540(int *param_1,int param_2)

{
  int iVar1;
  int *piVar2;
  int iVar3;
  int iVar4;
  int local_24 [9];
  
  piVar2 = local_24;
  iVar1 = 0;
  do {
    *piVar2 = iVar1;
    iVar1 = iVar1 + 1;
    piVar2 = piVar2 + 1;
  } while (iVar1 < 9);
  FUN_004052f0(local_24,9);
  iVar1 = (int)local_24 - (int)param_1;
  iVar3 = param_2 - (int)param_1;
  iVar4 = 4;
  do {
    *param_1 = *(int *)(iVar1 + (int)param_1) + 2;
    *(undefined4 *)(iVar3 + (int)param_1) = 1;
    param_1 = param_1 + 1;
    iVar4 = iVar4 + -1;
  } while (iVar4 != 0);
  return;
}

