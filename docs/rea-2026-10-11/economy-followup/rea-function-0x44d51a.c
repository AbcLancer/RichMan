
undefined4 * FUN_0044d4c0(void)

{
  int iVar1;
  int iVar2;
  void *pvVar3;
  undefined4 *puVar4;
  undefined4 uVar5;
  undefined4 *this;
  int *piVar6;
  undefined **ppuVar7;
  undefined4 uStack00000054;
  undefined4 uStack00000068;
  void *in_stack_00005e64;
  undefined *local_c [3];
  
  local_c[2] = (undefined *)0xffffffff;
  local_c[1] = &LAB_00492ce9;
  local_c[0] = ExceptionList;
  ExceptionList = local_c;
  FUN_004854d0();
  FUN_00457870(this);
  *this = &PTR_FUN_00495fd4;
  FUN_00457ad0(this,0,0,0x100,0xea);
  iVar1 = FUN_0045b0a0(DAT_00502ec4,&DAT_0049f650);
  this[0x32] = iVar1;
  local_c[0] = &DAT_0049f638;
  local_c[1] = &DAT_0049f620;
  local_c[2] = &DAT_0049f608;
  ppuVar7 = local_c;
  piVar6 = this + 0x33;
  iVar1 = 3;
  do {
    iVar2 = FUN_0045b0a0(DAT_00502ec4,*ppuVar7);
    *piVar6 = iVar2;
    ppuVar7 = ppuVar7 + 1;
    piVar6 = piVar6 + 1;
    iVar1 = iVar1 + -1;
  } while (iVar1 != 0);
  pvVar3 = operator_new(0xe8);
  if (pvVar3 == (void *)0x0) {
    puVar4 = (undefined4 *)0x0;
  }
  else {
    puVar4 = FUN_004482d0();
  }
  this[0x37] = puVar4;
  FUN_00448750(puVar4,(byte *)s_uitex_casino2_exit_tga_0049f5f0,
               (byte *)s_uitex_casino2_exit_tga_0049f5f0,(byte *)0x0);
  FUN_00457ad0((void *)this[0x37],0xbc,0xb1,0xf3,0xce);
  FUN_004579d0(this,this[0x37]);
  uVar5 = FUN_0043ad60(&DAT_004e1b00,(byte *)s_uitex_casino2_mark_tga_0049f5d8);
  this[0x38] = uVar5;
  uVar5 = FUN_0043ad60(&DAT_004e1b00,(byte *)s_uitex_casino2_cursor_tga_0049f5bc);
  this[0x39] = uVar5;
  FUN_00457e90(this,0);
  FUN_00457ed0(this,0);
  puVar4 = (undefined4 *)&stack0x000053dc;
  iVar1 = 8;
  do {
    FUN_00403ee0(puVar4);
    puVar4 = puVar4 + 0x11;
    iVar1 = iVar1 + -1;
  } while (iVar1 != 0);
  uVar5 = FUN_00477850();
  this[0x46] = uVar5;
  FUN_004778e0(&stack0x00000008,s_gfxscript_ui_add_gbf_0049efd0);
  uStack00000054 = 0;
  uStack00000068 = 0;
  pvVar3 = FUN_004777d0(*(void **)(DAT_0050d0d4 + 0xc0),(undefined4 *)&stack0x00000008);
  this[0x47] = pvVar3;
  ExceptionList = in_stack_00005e64;
  return this;
}

