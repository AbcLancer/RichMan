
void __fastcall FUN_0044d0b0(int param_1)

{
  int iVar1;
  undefined4 *puVar2;
  undefined4 *puVar3;
  int local_c [3];
  
  if (*(int *)(param_1 + 0x120) == 1) {
    return;
  }
  if (*(int *)(param_1 + 0x11c) == 0) {
    return;
  }
  *(undefined4 *)(param_1 + 0x120) = 1;
  FUN_00457e90(*(void **)(param_1 + 0x104),0);
  FUN_0044d190(local_c);
  iVar1 = FUN_00429c60(local_c);
  iVar1 = iVar1 * *(int *)(param_1 + 0x11c);
  if (100000 < iVar1) {
    if (iVar1 < 0x30d41) {
      iVar1 = FUN_00405130(0,10);
      if (4 < iVar1) goto LAB_0044d148;
    }
    else {
      iVar1 = FUN_00405130(0,10);
      if (8 < iVar1) goto LAB_0044d148;
    }
    FUN_0044d190(local_c);
  }
LAB_0044d148:
  puVar2 = (undefined4 *)&stack0xfffffff0;
  puVar3 = (undefined4 *)(param_1 + 0xd8);
  iVar1 = 3;
  do {
    puVar2 = puVar2 + 1;
    FUN_0044a480((void *)*puVar3,*puVar2,2);
    puVar3 = puVar3 + 1;
    iVar1 = iVar1 + -1;
  } while (iVar1 != 0);
  *(undefined4 *)(param_1 + 0x118) = 0;
  return;
}

