
undefined4 * FUN_0044a8a0(void)

{
  undefined4 *puVar1;
  void *pvVar2;
  undefined4 *this;
  int iVar3;
  undefined4 uStack00000048;
  undefined4 uStack00000050;
  undefined4 uStack0000005c;
  undefined4 uStack00000064;
  void *in_stack_00005e58;
  void *local_c;
  undefined1 *local_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  local_8 = &LAB_00492b99;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_004854d0();
  FUN_00457870(this);
  *this = &PTR_FUN_00495ee0;
  FUN_00457ad0(this,0,0,0x40,0x3d);
  FUN_00457c90(this,&DAT_0049f35c);
  FUN_00457b30(this,0,0,0x40,0x3d);
  local_c = operator_new(0xe8);
  if (local_c == (void *)0x0) {
    puVar1 = (undefined4 *)0x0;
  }
  else {
    puVar1 = FUN_004482d0();
  }
  this[0x34] = puVar1;
  FUN_00448750(puVar1,(byte *)s_uitex_labar_go_tga_0049f330,(byte *)s_uitex_labar_go_dn_tga_0049f344
               ,(byte *)0x0);
  FUN_00457ad0((void *)this[0x34],0x17,5,0x40,0x38);
  FUN_00457b30((void *)this[0x34],0,0,0x2a,0x34);
  FUN_00457c70((void *)this[0x34],0xff,0xff,0xff,0);
  FUN_004579d0(this,this[0x34]);
  this[0x35] = *(undefined4 *)(DAT_00502ec4 + 0x4250);
  this[0x37] = 1;
  this[0x36] = 1;
  this[0x38] = 1;
  this[0x39] = 0;
  this[0x3e] = 0;
  FUN_00457c10(this,0.2975,-0.31666666);
  this[0x32] = 0;
  this[0x33] = 0xbff00000;
  puVar1 = (undefined4 *)&stack0x000053d0;
  iVar3 = 8;
  do {
    FUN_00403ee0(puVar1);
    puVar1 = puVar1 + 0x11;
    iVar3 = iVar3 + -1;
  } while (iVar3 != 0);
  FUN_00476dd0(&local_4,0);
  uStack00000048 = 2;
  uStack0000005c = 2;
  uStack00000050 = 0x24;
  uStack00000064 = 0x44;
  pvVar2 = FUN_004777d0(*(void **)(DAT_0050d0d4 + 0xc0),&local_4);
  this[0x40] = 0;
  this[0x3c] = pvVar2;
  this[0x3d] = 0;
  this[0x41] = 0;
  ExceptionList = in_stack_00005e58;
  return this;
}

