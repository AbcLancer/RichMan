
undefined4 * __fastcall FUN_0044efc0(undefined4 *param_1)

{
  int iVar1;
  undefined4 uVar2;
  void *pvVar3;
  undefined4 *this;
  uint uVar4;
  uint uVar5;
  int *piVar6;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00492d83;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_00457870(param_1);
  uVar4 = 0;
  local_4 = 0;
  *param_1 = &PTR_FUN_00496054;
  FUN_00457ad0(param_1,0,0,0x100,0x100);
  iVar1 = FUN_0045b0a0(DAT_00502ec4,&DAT_0049f6e0);
  param_1[0x60] = iVar1;
  uVar2 = FUN_0043ad60(&DAT_004e1b00,(byte *)s_uitex_other_star_tga_0049f14c);
  param_1[0x5e] = uVar2;
  piVar6 = param_1 + 0x32;
  do {
    uVar5 = uVar4 & 0x80000001;
    if ((int)uVar5 < 0) {
      uVar5 = (uVar5 - 1 | 0xfffffffe) + 1;
    }
    pvVar3 = operator_new(0xe8);
    local_4._0_1_ = 1;
    if (pvVar3 == (void *)0x0) {
      this = (undefined4 *)0x0;
    }
    else {
      this = FUN_004482d0();
    }
    iVar1 = ((int)uVar4 / 2) * 0x5a;
    local_4 = (uint)local_4._1_3_ << 8;
    *piVar6 = (int)this;
    FUN_00457ad0(this,uVar5 * 0x70 + 0x25,iVar1 + 0x44,uVar5 * 0x70 + 0x65,iVar1 + 0x84);
    *(undefined4 *)(*piVar6 + 0x68) = 1;
    FUN_004579d0(param_1,*piVar6);
    uVar4 = uVar4 + 1;
    piVar6 = piVar6 + 1;
  } while ((int)uVar4 < 4);
  FUN_00457e90(param_1,0);
  FUN_00457ed0(param_1,0);
  param_1[0x5f] = 0xffffffff;
  FUN_00457c10(param_1,-0.345,-0.23333333);
  ExceptionList = local_c;
  return param_1;
}

