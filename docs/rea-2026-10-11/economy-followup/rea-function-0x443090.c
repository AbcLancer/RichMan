
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_00443080(void)

{
  undefined4 *puVar1;
  undefined4 *puVar2;
  int extraout_ECX;
  int iVar3;
  undefined4 *puVar4;
  float *pfVar5;
  undefined1 *puVar6;
  int iVar7;
  undefined4 uStack00000008;
  int iStack00000010;
  int iStack00000014;
  void *pvStack00000018;
  float in_stack_0000001c;
  undefined4 in_stack_00000020;
  float in_stack_00000024;
  float in_stack_00000028;
  undefined4 in_stack_0000002c;
  float in_stack_00000030;
  float in_stack_00000034;
  undefined4 in_stack_00000038;
  float in_stack_0000003c;
  float in_stack_00000040;
  undefined4 in_stack_00000044;
  float in_stack_00000048;
  float in_stack_00000054;
  float in_stack_00000060;
  undefined4 uStack00000064;
  undefined4 uStack000000a4;
  
  FUN_004854d0();
  if (*(int *)(extraout_ECX + 0x11970) != 0) {
    uStack00000064 = *(undefined4 *)(extraout_ECX + 0x11978);
    uStack000000a4 = 1;
    iStack00000010 = extraout_ECX;
    pvStack00000018 = (void *)FUN_0047ad50(*(void **)(DAT_0050d0d4 + 0xbc),0x15);
    puVar1 = &stack0x00000024;
    iVar3 = 4;
    do {
      puVar1[-2] = 0;
      puVar1[-1] = 0;
      *puVar1 = 0;
      puVar1 = puVar1 + 3;
      iVar3 = iVar3 + -1;
    } while (iVar3 != 0);
    puVar6 = &stack0x000000a8;
    iVar3 = 0x100;
    uStack00000008 = 0x40000000;
    do {
      FUN_00402ef0(puVar6,0xc,4,&LAB_0040dba0);
      puVar6 = puVar6 + 0x44;
      iVar3 = iVar3 + -1;
    } while (iVar3 != 0);
    iStack00000014 = 0;
    iVar3 = extraout_ECX;
    if (0 < *(int *)(extraout_ECX + 0x11970)) {
      iVar7 = -0x88;
      puVar1 = (undefined4 *)&stack0x000000e8;
      pfVar5 = (float *)(extraout_ECX + 0x70);
      do {
        if (pfVar5[1] == 0.0) {
          *puVar1 = 0xff009600;
        }
        else if (DAT_004a603c == 0) {
          *puVar1 = 0xffb40000;
        }
        else {
          *puVar1 = 0xff0000b4;
        }
        puVar1[-1] = 0x3f800000;
        puVar1[-2] = 0x3f800000;
        in_stack_0000002c = uStack00000008;
        in_stack_00000020 = uStack00000008;
        in_stack_00000030 = (ABS((float)((float10)0.5 - (float10)_DAT_0049eea0)) + 0.6) * *pfVar5;
        in_stack_00000038 = uStack00000008;
        puVar1[-3] = 0;
        in_stack_0000001c = -in_stack_00000030;
        puVar1[-4] = 0;
        in_stack_00000044 = uStack00000008;
        in_stack_00000024 = in_stack_0000001c;
        in_stack_00000028 = in_stack_0000001c;
        in_stack_00000034 = in_stack_00000030;
        in_stack_0000003c = in_stack_00000030;
        in_stack_00000040 = in_stack_00000030;
        in_stack_00000048 = in_stack_0000001c;
        in_stack_00000054 = in_stack_0000001c;
        in_stack_00000060 = in_stack_0000001c;
        FUN_004041c0(pfVar5 + -0x10,(int)&stack0x0000001c,4);
        puVar4 = &stack0x0000001c;
        puVar2 = puVar1 + -0xf;
        iVar3 = 4;
        do {
          puVar2[-1] = *puVar4;
          *puVar2 = *(undefined4 *)(iVar7 + -4 + (int)puVar2);
          puVar2[1] = *(undefined4 *)(iVar7 + (int)puVar2);
          puVar4 = puVar4 + 3;
          puVar2 = puVar2 + 3;
          iVar3 = iVar3 + -1;
        } while (iVar3 != 0);
        iStack00000014 = iStack00000014 + 1;
        pfVar5 = pfVar5 + 0x12;
        iVar7 = iVar7 + -0x44;
        puVar1 = puVar1 + 0x11;
        iVar3 = iStack00000010;
      } while (iStack00000014 < *(int *)(iStack00000010 + 0x11970));
    }
    FUN_0046ca50(pvStack00000018,&stack0x000000a8,*(int *)(iVar3 + 0x11970),
                 *(undefined4 *)(iVar3 + 0x11974));
    *(undefined4 *)(iVar3 + 0x11970) = 0;
  }
  return;
}

