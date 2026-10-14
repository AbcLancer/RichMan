
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

undefined4 FUN_00432470(void)

{
  undefined4 *puVar1;
  int iVar2;
  void *pvVar3;
  undefined4 uVar4;
  int *piVar5;
  int iVar6;
  int iVar7;
  undefined4 *puVar8;
  undefined4 *local_198;
  char local_18c [256];
  undefined4 auStack_8c [25];
  void *pvStack_28;
  undefined4 uStack_18;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_0049262c;
  pvStack_c = ExceptionList;
  iVar6 = 0;
  local_198 = &DAT_004fdff8;
  puVar8 = &DAT_004fdf64;
  puVar1 = &DAT_004fe040;
  ExceptionList = &pvStack_c;
  do {
    iVar7 = 0;
    do {
      iVar2 = FUN_00431e70(iVar6);
      FUN_00431e90(iVar2);
      FUN_00485290(local_18c,(byte *)s_uitex_pet__s___2d_tga_0049e92c);
      pvVar3 = (void *)(**(code **)(*DAT_0050d0d4 + 4))(local_18c);
      *puVar1 = pvVar3;
      FUN_00479f30(pvVar3,1);
      iVar7 = iVar7 + 1;
      puVar1 = puVar1 + 1;
    } while (iVar7 < 10);
    iVar7 = 0;
    do {
      pvVar3 = operator_new(200);
      uStack_4 = 0;
      if (pvVar3 == (void *)0x0) {
        uVar4 = 0;
      }
      else {
        uVar4 = FUN_0046dc20((int)pvVar3);
      }
      iVar7 = iVar7 + 1;
      uStack_4 = 0xffffffff;
      *puVar8 = uVar4;
      iVar2 = FUN_00431e70(iVar6);
      FUN_00431e90(iVar2);
      FUN_00485290(local_18c,(byte *)s_uitex_pet__s___2d_tga_0049e92c);
      FUN_0046dd10((void *)*puVar8,local_18c,0);
      puVar8 = puVar8 + 1;
    } while (iVar7 < 4);
    iVar7 = 0;
    do {
      pvVar3 = operator_new(200);
      uStack_4 = 1;
      if (pvVar3 == (void *)0x0) {
        uVar4 = 0;
      }
      else {
        uVar4 = FUN_0046dc20((int)pvVar3);
      }
      *local_198 = uVar4;
      uStack_4 = 0xffffffff;
      iVar2 = FUN_00431e70(iVar6);
      FUN_00431e90(iVar2);
      FUN_00485290(local_18c,(byte *)s_uitex_pet__s___2d_tga_0049e92c);
      FUN_0046dd10((void *)*local_198,local_18c,0);
      iVar7 = iVar7 + 1;
      local_198 = local_198 + 1;
    } while (iVar7 < 2);
    iVar6 = iVar6 + 1;
  } while ((int)puVar1 < 0x4fe1a8);
  FUN_0046dcc0(auStack_8c);
  uStack_18 = 0;
  DAT_004fdf60 = (int *)(**(code **)(*DAT_0050d0d4 + 4))(0);
  (**(code **)(*DAT_004fdf60 + 4))
            (*(undefined4 *)(DAT_004fdfb4 + 0x80),*(undefined4 *)(DAT_004fdfb4 + 0x84),5,1,2,
             *(undefined4 *)(DAT_004fdfb4 + 0xb8));
  puVar1 = &DAT_004fe1b4;
  do {
    piVar5 = (int *)(**(code **)(*DAT_0050d0d4 + 4))(0);
    iVar6 = DAT_004fe020;
    *puVar1 = piVar5;
    (**(code **)(*piVar5 + 4))
              (*(undefined4 *)(iVar6 + 0x80),*(undefined4 *)(iVar6 + 0x84),5,1,2,
               *(undefined4 *)(iVar6 + 0xb8));
    puVar1 = puVar1 + 1;
  } while ((int)puVar1 < 0x4fe1bc);
  puVar1 = &DAT_004fe1bc;
  do {
    FUN_00485290(&stack0xfffffe58,&DAT_0049e914);
    pvVar3 = (void *)(**(code **)(*DAT_0050d0d4 + 4))(&stack0xfffffe58);
    *puVar1 = pvVar3;
    FUN_00479f30(pvVar3,1);
    puVar1 = puVar1 + 1;
  } while ((int)puVar1 < 0x4fe1cc);
  _DAT_004fe1a8 = 0;
  DAT_004fdff4 = 0;
  _DAT_004fdf50 = 1;
  _DAT_004fe1ac = 2;
  _DAT_004fdf54 = 5;
  _DAT_004fe1b0 = 6;
  _DAT_004fdf58 = 9;
  DAT_004fdf5c = 0xffffffff;
  ExceptionList = pvStack_28;
  return 1;
}

