
void __cdecl FUN_004149e0(undefined4 *param_1,undefined4 *param_2,int param_3,undefined4 param_4)

{
  undefined4 uVar1;
  int *piVar2;
  int iVar3;
  
  iVar3 = 0;
  piVar2 = &DAT_004ba0f4;
  do {
    if (*(float *)(*piVar2 + 0x28) < 0.0) {
      uVar1 = FUN_004328d0(param_3,0,0);
      FUN_00418380((void *)(&DAT_004ba0f4)[iVar3],uVar1,param_1,param_2,0x40000000,param_4);
      return;
    }
    piVar2 = piVar2 + 1;
    iVar3 = iVar3 + 1;
  } while ((int)piVar2 < 0x4ba114);
  return;
}

