
undefined4 * __fastcall FUN_0044e280(undefined4 *param_1)

{
  int iVar1;
  void *pvVar2;
  undefined4 *this;
  uint uVar3;
  int *piVar4;
  uint uVar5;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00492d33;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_00457870(param_1);
  local_4 = 0;
  *param_1 = &PTR_FUN_00496010;
  FUN_00457c90(param_1,(byte *)s_uitex_other_cardshop_tga_0049f6a0);
  FUN_00457ad0(param_1,0,0,0x100,0xea);
  FUN_00457b30(param_1,0,0,0x100,0xea);
  uVar5 = 0;
  piVar4 = param_1 + 0x32;
  do {
    pvVar2 = operator_new(0xe8);
    local_4._0_1_ = 1;
    if (pvVar2 == (void *)0x0) {
      this = (undefined4 *)0x0;
    }
    else {
      this = FUN_004482d0();
    }
    local_4 = (uint)local_4._1_3_ << 8;
    *piVar4 = (int)this;
    FUN_00448750(this,(byte *)s_uitex_other_cardshop1_tga_0049f684,
                 (byte *)s_uitex_other_cardshop1_tga_0049f684,(byte *)0x0);
    uVar3 = uVar5 & 0x80000001;
    if ((int)uVar3 < 0) {
      uVar3 = (uVar3 - 1 | 0xfffffffe) + 1;
    }
    iVar1 = ((int)uVar5 / 2) * 0x1c;
    FUN_00457ad0((void *)*piVar4,uVar3 * 0x5a + 0x26,iVar1 + 0x65,uVar3 * 0x5a + 0x7d,iVar1 + 0x7e);
    FUN_00457c70((void *)*piVar4,0,0,0,0);
    FUN_004579d0(param_1,*piVar4);
    uVar5 = uVar5 + 1;
    piVar4 = piVar4 + 1;
  } while ((int)uVar5 < 8);
  FUN_00457e90(param_1,0);
  param_1[0xc2] = 0;
  FUN_00457c10(param_1,-0.315,-0.17333333);
  ExceptionList = local_c;
  return param_1;
}

