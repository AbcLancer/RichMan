// ===== 420a80 → 不在任何已知函数内

// ===== 4364a0 → FUN_004364a0 @ 004364a0（就是入口）  大小 26 字节

undefined4 __fastcall FUN_004364a0(void *param_1)

{
  int iVar1;
  
  if (*(int *)((int)param_1 + 0x3c) != 2) {
    iVar1 = FUN_00435fe0(param_1,0xb);
    if (iVar1 == 0) {
      return 1;
    }
  }
  return 0;
}



// ===== 4364c0 → FUN_004364c0 @ 004364c0（就是入口）  大小 84 字节

/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

undefined4 __fastcall FUN_004364c0(undefined *param_1)

{
  int iVar1;
  
  if ((*(int *)(param_1 + 0x1c0) == 0) || (*(int *)(param_1 + 0x3c) == 300)) {
    return 0;
  }
  if (param_1 != &DAT_004e1b80 + DAT_004e2a84 * 0x1e0) {
    iVar1 = FUN_00435fe0(param_1,0xb);
    if (iVar1 != 0) {
      return 0;
    }
    if (_DAT_00495460 <= *(double *)(DAT_00502edc + 8)) {
      return 0;
    }
  }
  return 1;
}



// ===== 420350 → 不在任何已知函数内

// ===== 420550 → 不在任何已知函数内

// ===== 41fa20 → FUN_0041fa20 @ 0041fa20（就是入口）  大小 223 字节

undefined4 __cdecl FUN_0041fa20(undefined4 param_1,uint param_2,int param_3,int param_4)

{
  int iVar1;
  int iVar2;
  undefined4 *this;
  int iVar3;
  void *this_00;
  
  iVar1 = *(int *)(*(int *)(param_3 + 0xc) + 0x78);
  iVar2 = FUN_0042bb50(iVar1);
  if (*(int *)(iVar2 + 0x30) == 0) {
    return 1;
  }
  this = FUN_00427d70(6,0,0x40080000);
  this[6] = 0;
  this[7] = 0x3ff00000;
  this[0x6d] = param_3;
  iVar3 = FUN_0041ce10(&DAT_004ece18,param_4 % 3 + 3,param_4 / 3 + 1,1);
  FUN_00428520(this,*(void **)(iVar1 + 0x28),*(int *)(iVar1 + 0x2c),iVar3);
  FUN_00428590((int)this);
  iVar1 = *(int *)(iVar2 + 0x34);
  if (iVar1 != 0) {
    iVar2 = FUN_00435620(param_3);
    if (iVar1 != iVar2) {
      this_00 = (void *)FUN_00440170(iVar1);
      FUN_00436810(this_00,param_2,0);
      FUN_0043c5e0(DAT_004fe7ac,0x404,(uint *)(*(int *)(param_3 + 0x38) << 8 | param_2),(int)this_00
                  );
    }
  }
  return 0;
}



// ===== 41f710 → FUN_0041f710 @ 0041f710（就是入口）  大小 228 字节

/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

undefined4 __cdecl FUN_0041f710(undefined4 param_1,uint param_2,int param_3)

{
  int iVar1;
  int iVar2;
  int iVar3;
  byte *pbVar4;
  void *this;
  
  iVar1 = *(int *)(*(int *)(param_3 + 0xc) + 0x78);
  iVar2 = FUN_0042bb50(iVar1);
  iVar2 = *(int *)(iVar2 + 0x34);
  iVar3 = FUN_00435620(param_3);
  if (iVar2 != iVar3) {
    FUN_0043cb00(DAT_004fe7ac,0x3ff,(byte *)((uint)(*(int *)(iVar1 + 0x28) - DAT_004e3844) / 0x58),
                 *(byte **)(iVar1 + 0x2c));
    pbVar4 = (byte *)FUN_00435620(param_3);
    FUN_0042b510(*(void **)(iVar1 + 0x28),*(uint *)(iVar1 + 0x2c),pbVar4);
    FUN_0042f9b0((byte *)0x1e,*(void **)(*(int *)(param_3 + 0xc) + 0x78));
    FUN_0042b1b0(*(void **)(iVar1 + 0x28),*(int *)(iVar1 + 0x2c));
    if (iVar2 != 0) {
      this = (void *)FUN_00440170(iVar2);
      _DAT_004fdb24 = param_3;
      DAT_004fdb3c = *(undefined4 *)(iVar1 + 0x3c);
      _DAT_004fdb20 = this;
      FUN_0042ab30(&DAT_005090b0,0x3ef,(int *)&DAT_004fdb20);
      FUN_00436810(this,param_2,0);
      FUN_0043c5e0(DAT_004fe7ac,0x404,(uint *)(*(int *)(param_3 + 0x38) << 8 | param_2),(int)this);
    }
  }
  return 0;
}



// ===== 41e460 → FUN_0041e460 @ 0041e460（就是入口）  大小 1046 字节

undefined4 __fastcall FUN_0041e460(void *param_1)

{
  char cVar1;
  int iVar2;
  undefined4 *puVar3;
  uint *puVar4;
  char *pcVar5;
  int iVar6;
  int *piVar7;
  uint *puVar8;
  int iVar9;
  uint uVar10;
  uint uVar11;
  int *piVar12;
  undefined4 *puVar13;
  int *piVar14;
  char *pcVar15;
  undefined4 *local_478;
  int local_474;
  char local_464 [4];
  uint local_460 [8];
  char local_440 [4];
  char local_43c [16];
  char local_42c [256];
  char local_32c [256];
  int local_22c;
  int local_228;
  int local_224;
  int local_220;
  int local_21c;
  int local_218;
  int local_214;
  int local_210;
  int local_20c;
  int local_208;
  int local_204;
  char local_200 [256];
  char local_100 [256];
  
  if (DAT_004e1b1c == 0) {
    local_478 = &DAT_004f2a48;
    puVar13 = &DAT_004f2a48;
  }
  else {
    puVar13 = &DAT_004d9078;
    local_478 = &DAT_004d9078;
  }
  FUN_0047e940(DAT_00508d24,puVar13[0xf7]);
  FUN_00485290(local_100,(byte *)s_mainmenu_cardset__s_card_crd_0049df60);
  iVar2 = FUN_0047e960(DAT_00508d24,0);
  *(undefined4 *)((int)param_1 + 28000) = 0;
  puVar3 = (undefined4 *)((int)param_1 + 0x6d6c);
  iVar9 = 7;
  do {
    puVar3[-1] = 0xffffffff;
    *puVar3 = 0;
    puVar3 = puVar3 + 3;
    iVar9 = iVar9 + -1;
  } while (iVar9 != 0);
  puVar4 = FUN_00402430(DAT_004a6040,local_100,0x201);
  FUN_004026c0(DAT_004a6040,local_464,4,(int)puVar4);
  FUN_004026c0(DAT_004a6040,(char *)local_460,0x20,(int)puVar4);
  iVar9 = 0;
  puVar8 = local_460;
  do {
    iVar6 = iVar9 + 0x3e0;
    iVar9 = iVar9 + 1;
    *puVar8 = (uint)*(byte *)(iVar6 + (int)puVar13);
    puVar8 = puVar8 + 1;
  } while (iVar9 < 8);
  FUN_004026c0(DAT_004a6040,(char *)((int)param_1 + 28000),4,(int)puVar4);
  iVar9 = 0;
  local_474 = 0;
  if (0 < *(int *)((int)param_1 + 28000)) {
    do {
      FUN_004026c0(DAT_004a6040,local_440,0x240,(int)puVar4);
      uVar10 = 0xffffffff;
      piVar12 = (int *)(iVar9 * 0x230 + (int)param_1);
      pcVar5 = local_43c;
      do {
        pcVar15 = pcVar5;
        if (uVar10 == 0) break;
        uVar10 = uVar10 - 1;
        pcVar15 = pcVar5 + 1;
        cVar1 = *pcVar5;
        pcVar5 = pcVar15;
      } while (cVar1 != '\0');
      uVar10 = ~uVar10;
      *piVar12 = iVar9;
      piVar14 = (int *)(pcVar15 + -uVar10);
      piVar7 = piVar12;
      for (uVar11 = uVar10 >> 2; piVar7 = piVar7 + 1, uVar11 != 0; uVar11 = uVar11 - 1) {
        *piVar7 = *piVar14;
        piVar14 = piVar14 + 1;
      }
      for (uVar10 = uVar10 & 3; uVar10 != 0; uVar10 = uVar10 - 1) {
        *(char *)piVar7 = (char)*piVar14;
        piVar14 = (int *)((int)piVar14 + 1);
        piVar7 = (int *)((int)piVar7 + 1);
      }
      uVar10 = 0xffffffff;
      pcVar5 = local_32c;
      do {
        pcVar15 = pcVar5;
        if (uVar10 == 0) break;
        uVar10 = uVar10 - 1;
        pcVar15 = pcVar5 + 1;
        cVar1 = *pcVar5;
        pcVar5 = pcVar15;
      } while (cVar1 != '\0');
      uVar10 = ~uVar10;
      piVar7 = (int *)(pcVar15 + -uVar10);
      piVar14 = piVar12 + 5;
      for (uVar11 = uVar10 >> 2; uVar11 != 0; uVar11 = uVar11 - 1) {
        *piVar14 = *piVar7;
        piVar7 = piVar7 + 1;
        piVar14 = piVar14 + 1;
      }
      for (uVar10 = uVar10 & 3; uVar10 != 0; uVar10 = uVar10 - 1) {
        *(char *)piVar14 = (char)*piVar7;
        piVar7 = (int *)((int)piVar7 + 1);
        piVar14 = (int *)((int)piVar14 + 1);
      }
      pcVar5 = FUN_00401d40(local_42c,&DAT_0049df5c);
      uVar10 = 0xffffffff;
      pcVar5 = pcVar5 + 1;
      do {
        pcVar15 = pcVar5;
        if (uVar10 == 0) break;
        uVar10 = uVar10 - 1;
        pcVar15 = pcVar5 + 1;
        cVar1 = *pcVar5;
        pcVar5 = pcVar15;
      } while (cVar1 != '\0');
      uVar10 = ~uVar10;
      piVar7 = (int *)(pcVar15 + -uVar10);
      piVar14 = piVar12 + 0x50;
      for (uVar11 = uVar10 >> 2; uVar11 != 0; uVar11 = uVar11 - 1) {
        *piVar14 = *piVar7;
        piVar7 = piVar7 + 1;
        piVar14 = piVar14 + 1;
      }
      for (uVar10 = uVar10 & 3; uVar10 != 0; uVar10 = uVar10 - 1) {
        *(char *)piVar14 = (char)*piVar7;
        piVar7 = (int *)((int)piVar7 + 1);
        piVar14 = (int *)((int)piVar14 + 1);
      }
      piVar12[0x45] = local_22c;
      piVar12[0x49] = local_224;
      piVar12[0x48] = local_228;
      piVar12[0x46] = local_220;
      piVar12[0x47] = local_21c;
      piVar12[0x4a] = local_218;
      piVar12[0x4b] = local_214;
      piVar12[0x4c] = local_210;
      piVar12[0x4d] = local_20c;
      piVar12[0x4e] = local_208;
      piVar12[0x4f] = local_204 + -1;
      if (iVar9 == 0x16) {
        piVar12[0x4f] = -1;
      }
      piVar12[0x86] = -1;
      piVar12[0x87] = 0;
      piVar12[0x88] = 0;
      piVar12[0x46] = (uint)*(byte *)((int)local_478 + iVar9 + 1000);
      iVar6 = FUN_0041e880(iVar9,(int)piVar12,(int *)local_460);
      if (iVar6 == 0) {
        piVar12[0x46] = 0;
      }
      iVar6 = 0;
      piVar12[0x8a] = local_474;
      if (0 < piVar12[0x46]) {
        piVar7 = (int *)((int)param_1 + (local_474 * 3 + 0x1b6f) * 4);
        do {
          piVar7[1] = 0;
          *piVar7 = iVar9;
          piVar7[-1] = -1;
          local_474 = local_474 + 1;
          piVar7 = piVar7 + 3;
          iVar6 = iVar6 + 1;
        } while (iVar6 < piVar12[0x46]);
      }
      piVar12[0x8b] = local_474 + -1;
      iVar9 = iVar9 + 1;
    } while (iVar9 < *(int *)((int)param_1 + 28000));
  }
  *(int *)((int)param_1 + 0x8528) = local_474;
  FUN_00402660(DAT_004a6040,puVar4);
  puVar8 = FUN_00402430(DAT_004a6040,s_config_card_txt_0049df4c,0x401);
  if (puVar8 != (uint *)0x0) {
    FUN_00402c20(DAT_004a6040,local_200,0x100,(int)puVar8);
    iVar9 = 0;
    if (0 < *(int *)((int)param_1 + 28000)) {
      do {
        FUN_00402c20(DAT_004a6040,local_200,0x10,(int)puVar8);
        FUN_00486797(local_200,&DAT_0049c1f4);
        iVar9 = iVar9 + 1;
      } while (iVar9 < *(int *)((int)param_1 + 28000));
    }
    FUN_00402660(DAT_004a6040,puVar8);
  }
  FUN_0047e960(DAT_00508d24,iVar2);
  if (DAT_004e1b1c != 0) {
    FUN_0041e8c0((int)param_1);
  }
  FUN_00422270(param_1);
  *(undefined4 *)((int)param_1 + 0x8530) = 0;
  puVar13 = (undefined4 *)((int)param_1 + 0x8534);
  for (iVar2 = 10; iVar2 != 0; iVar2 = iVar2 + -1) {
    *puVar13 = 0;
    puVar13 = puVar13 + 1;
  }
  *(undefined4 *)((int)param_1 + 0x855c) = 0xffffffff;
  *(undefined4 *)((int)param_1 + 0x852c) = *(undefined4 *)((int)param_1 + 0x8528);
  return 1;
}



// ===== 41f080 → FUN_0041f080 @ 0041f080（就是入口）  大小 83 字节

undefined4 __thiscall FUN_0041f080(void *this,int param_1)

{
  int iVar1;
  void *pvVar2;
  
  iVar1 = FUN_0041f060(this,param_1);
  pvVar2 = FUN_0041f040(this,*(int *)(iVar1 + 4));
  if (*(int *)((int)pvVar2 + 0x13c) == 999) {
    *(uint *)(iVar1 + 8) = *(uint *)(iVar1 + 8) | 1;
    return *(undefined4 *)((int)pvVar2 + 0x13c);
  }
  FUN_0041f0e0(this,param_1,*(int *)((int)pvVar2 + 0x13c));
  return *(undefined4 *)((int)pvVar2 + 0x13c);
}



// ===== 41f970 → 不在任何已知函数内

