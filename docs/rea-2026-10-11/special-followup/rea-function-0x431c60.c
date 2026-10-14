
bool __thiscall FUN_00431c60(void *this,byte *param_1,undefined4 param_2)

{
  int *piVar1;
  int iVar2;
  
  if (*(int *)(param_1 + 0x34) == -1) {
    return false;
  }
  piVar1 = (int *)FUN_00431ac0(this,*(int *)(param_1 + 0x34));
  iVar2 = FUN_00431b70(this,*piVar1);
  iVar2 = (**(code **)(iVar2 + 4))(piVar1,param_2);
  FUN_0043cb00(DAT_004fe7ac,0x12e,(byte *)*piVar1,param_1);
  FUN_0042be40(param_1);
  return iVar2 == 1;
}

