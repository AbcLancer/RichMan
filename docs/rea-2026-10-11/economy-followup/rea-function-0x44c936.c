
undefined4 * __fastcall FUN_0044c8e0(undefined4 *param_1)

{
  int iVar1;
  undefined4 uVar2;
  void *pvVar3;
  undefined4 *puVar4;
  char **ppcVar5;
  int *piVar6;
  char *local_11c [4];
  byte local_10c [256];
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00492cc3;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  local_11c[3] = (char *)param_1;
  FUN_00457870(param_1);
  local_4._0_1_ = 0;
  local_4._1_3_ = 0;
  *param_1 = &PTR_FUN_00495fb4;
  FUN_00457ad0(param_1,0,0,0xdc,0x100);
  iVar1 = FUN_0045b0a0(DAT_00502ec4,&DAT_0049f588);
  param_1[0x32] = iVar1;
  local_11c[0] = &DAT_0049f570;
  local_11c[1] = &DAT_0049f558;
  local_11c[2] = s_uitex_casino_7_tga_0049f544;
  ppcVar5 = local_11c;
  puVar4 = param_1 + 0x33;
  iVar1 = 3;
  do {
    uVar2 = FUN_0043ad60(&DAT_004e1b00,(byte *)*ppcVar5);
    *puVar4 = uVar2;
    ppcVar5 = ppcVar5 + 1;
    puVar4 = puVar4 + 1;
    iVar1 = iVar1 + -1;
  } while (iVar1 != 0);
  iVar1 = 0x29;
  piVar6 = param_1 + 0x36;
  do {
    pvVar3 = operator_new(0x270);
    local_4._0_1_ = 1;
    if (pvVar3 == (void *)0x0) {
      puVar4 = (undefined4 *)0x0;
    }
    else {
      puVar4 = FUN_0044a3f0(pvVar3,3,param_1 + 0x33);
    }
    local_4._0_1_ = 0;
    *piVar6 = (int)puVar4;
    FUN_00457c70(puVar4,0xff,0xff,0xff,0);
    FUN_00457ad0((void *)*piVar6,iVar1,0x96,iVar1 + 0x22,0xb6);
    FUN_004579d0(param_1,*piVar6);
    iVar1 = iVar1 + 0x2b;
    piVar6 = piVar6 + 1;
  } while (iVar1 < 0xaa);
  uVar2 = FUN_0043ad60(&DAT_004e1b00,&DAT_0049f52c);
  param_1[0x39] = uVar2;
  uVar2 = FUN_0043ad60(&DAT_004e1b00,&DAT_0049f514);
  param_1[0x3a] = uVar2;
  uVar2 = FUN_0043ad60(&DAT_004e1b00,&DAT_0049f4fc);
  param_1[0x3b] = uVar2;
  iVar1 = 0x11;
  piVar6 = param_1 + 0x3d;
  do {
    pvVar3 = operator_new(0xe8);
    local_4._0_1_ = 2;
    if (pvVar3 == (void *)0x0) {
      puVar4 = (undefined4 *)0x0;
    }
    else {
      puVar4 = FUN_004482d0();
    }
    *piVar6 = (int)puVar4;
    local_4._0_1_ = 0;
    FUN_00485290(local_10c,(byte *)s_uitex_casino_add_d_tga_0049f4e4);
    FUN_00448750((void *)*piVar6,local_10c,local_10c,(byte *)0x0);
    FUN_00457ad0((void *)*piVar6,iVar1,0xd3,iVar1 + 0x36,0xeb);
    FUN_00457c70((void *)*piVar6,0,0,0,0);
    FUN_004579d0(param_1,*piVar6);
    iVar1 = iVar1 + 0x37;
    piVar6 = piVar6 + 1;
  } while (iVar1 < 0xb6);
  pvVar3 = operator_new(0xe8);
  local_4._0_1_ = 3;
  if (pvVar3 == (void *)0x0) {
    puVar4 = (undefined4 *)0x0;
  }
  else {
    puVar4 = FUN_004482d0();
  }
  local_4._0_1_ = 0;
  param_1[0x40] = puVar4;
  FUN_00448750(puVar4,(byte *)s_uitex_casino_exit_tga_0049f4cc,
               (byte *)s_uitex_casino_exit_tga_0049f4cc,(byte *)0x0);
  FUN_00457ad0((void *)param_1[0x40],2,0x8f,0x1e,0xb9);
  FUN_004579d0(param_1,param_1[0x40]);
  pvVar3 = operator_new(0xe8);
  local_4._0_1_ = 4;
  if (pvVar3 == (void *)0x0) {
    puVar4 = (undefined4 *)0x0;
  }
  else {
    puVar4 = FUN_004482d0();
  }
  local_4 = (uint)local_4._1_3_ << 8;
  param_1[0x41] = puVar4;
  FUN_00448750(puVar4,&DAT_0049f4b4,&DAT_0049f4b4,(byte *)0x0);
  FUN_00457ad0((void *)param_1[0x41],0xb6,0x6e,0xd5,0x8b);
  FUN_004579d0(param_1,param_1[0x41]);
  uVar2 = FUN_0043ad60(&DAT_004e1b00,(byte *)s_uitex_casino_pull_1_tga_0049f49c);
  param_1[0x42] = uVar2;
  uVar2 = FUN_0043ad60(&DAT_004e1b00,(byte *)s_uitex_casino_pull_2_tga_0049f484);
  param_1[0x43] = uVar2;
  FUN_00457e90(param_1,0);
  FUN_00457ed0(param_1,0);
  FUN_00457c10(param_1,-0.92,-0.48);
  FUN_0044cc80((int)param_1);
  ExceptionList = local_c;
  return param_1;
}

