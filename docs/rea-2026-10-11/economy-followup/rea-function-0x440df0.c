
undefined4 __fastcall FUN_00440cd0(undefined4 *param_1)

{
  void *pvVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  undefined4 *puVar6;
  int *piVar7;
  int local_c;
  undefined4 *local_8;
  int local_4;
  
  if (DAT_004e1b1c == 0) {
    local_8 = &DAT_004f2a48;
    puVar6 = &DAT_004f2a48;
  }
  else {
    puVar6 = &DAT_004d9078;
    local_8 = &DAT_004d9078;
  }
  iVar4 = puVar6[0xf0];
  param_1[2] = iVar4 + 0x10;
  pvVar1 = _malloc((iVar4 + 0x10) * 0x3a8);
  param_1[1] = pvVar1;
  DAT_00508e20 = puVar6[0xf3];
  iVar4 = puVar6[0xf5];
  if (iVar4 == 0) {
    local_c = DAT_00508f70;
  }
  else if (iVar4 == 1) {
    local_c = DAT_00508f74;
  }
  else if (iVar4 == 2) {
    local_c = DAT_00508f78;
  }
  iVar4 = 0;
  iVar5 = 0;
  piVar7 = puVar6 + 1;
  local_4 = 8;
  do {
    if ((*piVar7 == 3) || (*piVar7 == 2)) {
      iVar2 = FUN_0047e920(DAT_00508d24,piVar7[-1]);
      iVar3 = DAT_00508e20;
      if (*piVar7 == 3) {
        iVar3 = DAT_00508e20 * local_c;
      }
      FUN_0043f5e0((void *)(iVar5 + param_1[1]),(char *)(iVar2 + 0x60),0,piVar7[-1],iVar3,
                   DAT_00508e24,DAT_00508e28);
      iVar4 = iVar4 + 1;
      iVar5 = iVar5 + 0x3a8;
    }
    piVar7 = piVar7 + 0x1e;
    local_4 = local_4 + -1;
  } while (local_4 != 0);
  param_1[3] = iVar4;
  iVar5 = 0;
  puVar6 = &DAT_004d9078;
  if (DAT_004e1b1c == 0) {
    puVar6 = &DAT_004f2a48;
  }
  iVar3 = FUN_0047e940(DAT_00508d24,puVar6[0xf7]);
  if (0 < *(int *)(iVar3 + 0x270)) {
    iVar4 = iVar4 * 0x3a8;
    piVar7 = (int *)(iVar3 + 0x40);
    do {
      FUN_0043f5e0((void *)(iVar4 + param_1[1]),(char *)(piVar7 + -4),1,-1,*piVar7,piVar7[1],0);
      iVar5 = iVar5 + 1;
      piVar7 = piVar7 + 6;
      iVar4 = iVar4 + 0x3a8;
    } while (iVar5 < *(int *)(iVar3 + 0x270));
  }
  iVar4 = local_8[0xf0] + *(int *)(iVar3 + 0x270);
  iVar5 = 0;
  param_1[2] = iVar4;
  if (0 < iVar4) {
    iVar4 = 0;
    do {
      *(int *)(iVar4 + 0x44 + param_1[1]) = iVar5;
      iVar5 = iVar5 + 1;
      iVar4 = iVar4 + 0x3a8;
    } while (iVar5 < (int)param_1[2]);
  }
  param_1[4] = 0;
  param_1[8] = 0;
  param_1[0xb] = 0;
  param_1[0xc] = 1;
  param_1[5] = 0;
  param_1[6] = 0;
  param_1[7] = 0;
  param_1[9] = 0;
  iVar4 = FUN_004418b0(param_1);
  param_1[10] = iVar4;
  *param_1 = 1;
  return 1;
}

