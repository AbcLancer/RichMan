
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_004243a0(void *this,void *param_1)

{
  byte bVar1;
  char cVar2;
  undefined4 *puVar3;
  void *this_00;
  void *pvVar4;
  int iVar5;
  uint uVar6;
  int iVar7;
  int *piVar8;
  char *pcVar9;
  char *pcVar10;
  ushort uVar11;
  uint uVar12;
  uint uVar13;
  float fVar14;
  int iVar15;
  undefined *puVar16;
  float *pfVar17;
  undefined1 *puVar18;
  uint local_5f8;
  uint local_5f4;
  uint local_5f0;
  byte local_5eb;
  byte local_5ea [2];
  uint local_5e8;
  float local_5e4;
  undefined1 local_5e0;
  char local_5df;
  char local_5de;
  char local_5dd;
  void *local_5dc;
  int local_5d8;
  int local_5d4;
  uint local_5d0;
  int local_5cc;
  short local_5c6;
  size_t local_5c4;
  undefined1 local_5bd;
  size_t local_5bc;
  short local_5b8;
  undefined1 local_5b5;
  uint local_5b4;
  short local_5ae;
  float local_5ac;
  uint local_5a8;
  short local_5a4;
  short local_5a2;
  uint local_5a0;
  uint local_59c;
  uint local_598;
  uint local_594;
  uint local_590;
  float local_58c;
  undefined4 local_588;
  undefined4 local_584;
  float local_580 [9];
  uint local_55c;
  uint local_558;
  float local_554;
  float local_550;
  undefined4 local_54c;
  int local_548;
  float local_544 [4];
  float local_534 [3];
  uint local_528;
  uint local_524;
  uint local_520;
  uint local_51c;
  uint local_518;
  undefined1 local_514;
  undefined1 local_513 [3];
  uint local_510;
  uint local_50c;
  uint local_508;
  uint local_504;
  uint local_500;
  uint local_4fc;
  uint local_4f8;
  uint local_4f4;
  uint local_4f0;
  uint local_4ec;
  undefined4 local_4e8;
  uint local_4e4;
  void *local_4e0;
  uint local_4dc;
  uint local_4d8;
  float local_4d4;
  uint local_4d0;
  float local_4cc [46];
  undefined1 local_414 [4];
  undefined *local_410;
  undefined *local_40c;
  int local_408;
  int local_404;
  undefined1 local_400 [4];
  int local_3fc;
  int local_3f8;
  int local_3f4;
  short local_3f0 [8];
  undefined1 local_3e0;
  undefined1 uStack_3df;
  undefined1 uStack_3de;
  undefined1 uStack_3dd;
  undefined1 uStack_3dc;
  undefined1 local_3db;
  undefined1 uStack_3da;
  undefined1 uStack_3d9;
  byte bStack_3d8;
  undefined1 local_37c [4];
  undefined *local_378;
  int local_364;
  undefined *local_358 [9];
  undefined4 local_334;
  short local_2d0;
  short local_2ce [99];
  short local_208;
  short local_206 [98];
  char acStack_141 [321];
  
  local_5d4 = 1;
  local_4e0 = this;
  FUN_0042fbb0(param_1,(undefined1 *)((int)this + 0x8008));
  if (local_5d4 == 0) {
    return;
  }
  do {
    FUN_0042fbb0(param_1,(undefined1 *)&local_5d4);
    if (local_5d4 < 0xd2) {
      if (local_5d4 == 0xd1) {
        FUN_0045a6f0((int)DAT_00500178);
      }
      else {
        switch(local_5d4) {
        case 2:
          if ((&DAT_004e1bbc)[DAT_004e2a84 * 0x78] == 1) {
            FUN_00434270(&DAT_004e1b80 + DAT_004e2a84 * 0x1e0,0);
          }
          break;
        case 6:
          iVar7 = FUN_0043a120(0x4e1b78);
          if (iVar7 != 0) {
            FUN_0042fc40(param_1,(undefined1 *)&local_5a0);
            FUN_0042fc80(param_1,(undefined4 *)local_3f0,(local_5a0 & 0xff) << 1);
            pvVar4 = (void *)FUN_0045a360((int)DAT_00500178);
            FUN_0044e3e0(pvVar4,local_3f0,local_5a0 & 0xff);
            FUN_00434280(&DAT_004e1b80 + DAT_004e2a84 * 0x1e0,200,
                         *(undefined4 *)((int)DAT_004fe7b0 + 0x8008));
          }
          break;
        case 0xb:
          iVar7 = FUN_0043a120(0x4e1b78);
          if (iVar7 != 0) {
            FUN_0045a270((int)DAT_00500178);
            FUN_00434280(&DAT_004e1b80 + DAT_004e2a84 * 0x1e0,0xc9,
                         *(undefined4 *)((int)DAT_004fe7b0 + 0x8008));
          }
          break;
        case 0xd:
          iVar7 = FUN_0043a120(0x4e1b78);
          if (iVar7 != 0) {
            FUN_0045a450((int)DAT_00500178);
            FUN_00434280(&DAT_004e1b80 + DAT_004e2a84 * 0x1e0,0xcb,
                         *(undefined4 *)((int)DAT_004fe7b0 + 0x8008));
          }
          break;
        case 0x11:
          ShowWindow(*(HWND *)(DAT_0050d0d4 + 8),5);
          FUN_00466720(1.0,(char *)0x0);
          FUN_004668b0(0);
          FUN_00401000(&DAT_0049e034);
          *(uint *)((int)DAT_00508d24 + 0xc4) = *(uint *)((int)DAT_00508d24 + 0xc4) | 0x10;
          if (*(int *)((int)DAT_00500178 + 0x5a4) == 0) {
            FUN_004572d0(DAT_00502edc,0,0x40240000,0);
            *(undefined4 *)((int)DAT_00500178 + 0x5a4) = 1;
          }
          if (*(int *)((int)DAT_00508d24 + 0x2a0) < 0) {
            iVar7 = 0;
            if (0 < DAT_004e2a80) {
              puVar16 = &DAT_004e1b80;
              do {
                FUN_00434270(puVar16,0);
                iVar7 = iVar7 + 1;
                puVar16 = puVar16 + 0x1e0;
              } while (iVar7 < DAT_004e2a80);
            }
            FUN_004275b0();
          }
          else {
            *(undefined4 *)((int)DAT_00508d24 + 0x2a0) = 0xffffffff;
            FUN_004275b0();
          }
          break;
        case 0x12:
          FUN_00401000(&DAT_0049e060);
          iVar7 = FUN_004271d0(param_1);
          if (iVar7 == 0) {
            FUN_0047c990((int)DAT_00508d24);
            *(undefined4 *)((int)param_1 + 0x8004) = 0;
            *(undefined4 *)((int)param_1 + 0x8000) = 0;
            return;
          }
          FUN_00401000(&DAT_0049e048);
          break;
        case 0x13:
          FUN_0042fc40(param_1,&local_5df);
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          uVar6 = (-(uint)((char)local_5f8 != '\x01') & 0x20) + 0x20;
          if (local_5df == '\0') {
            *(uint *)((int)DAT_00508d24 + 0xc4) = *(uint *)((int)DAT_00508d24 + 0xc4) & ~uVar6;
            if (uVar6 == 0x20) {
              FUN_00443d10(*(void **)((int)DAT_00500178 + 0x534),0);
            }
          }
          else {
            *(uint *)((int)DAT_00508d24 + 0xc4) = *(uint *)((int)DAT_00508d24 + 0xc4) | uVar6;
            if (uVar6 == 0x20) {
              FUN_00443d10(*(void **)((int)DAT_00500178 + 0x534),1);
            }
          }
          break;
        case 0x14:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042fc10(param_1,(undefined1 *)&local_2d0);
          FUN_0042fc80(param_1,(undefined4 *)local_2ce,local_2d0 * 2 + 2);
          FUN_00434d70(&DAT_004e1b80 + (local_5f8 & 0xff) * 0x1e0,(int)local_2d0,local_2ce,
                       (int)local_2ce[local_2d0]);
          break;
        case 0x15:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042fc10(param_1,(undefined1 *)&local_208);
          FUN_0042fc80(param_1,(undefined4 *)local_206,local_208 * 2 + 2);
          FUN_004349a0(&DAT_004e1b80 + (local_5f8 & 0xff) * 0x1e0,(int)local_208,local_206,
                       (int)local_206[local_208]);
          break;
        case 0x16:
          FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0041f140(&DAT_004d9498,(int)(short)local_5f0,local_5f8 & 0xff);
          break;
        case 0x17:
          FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
          FUN_0041f190(&DAT_004d9498,(int)(short)local_5f0);
          break;
        case 0x18:
          FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
          iVar7 = -1;
          local_378 = &DAT_004e1b80 + (local_5f4 >> 0x10 & 0xff) * 0x1e0;
          local_364 = FUN_0041f040(&DAT_004d9498,local_5f4 & 0xffff);
          if (local_378 != &DAT_004e1b80 + DAT_004e2a84 * 0x1e0) {
            iVar7 = 0x34;
          }
          if ((local_5f4 & 0xff000000) == 0) {
            if (iVar7 < 0) break;
          }
          else {
            iVar7 = 0x36;
          }
          puVar18 = local_37c;
          piVar8 = (int *)FUN_0042a8a0(&DAT_005090b0,iVar7);
          pcVar9 = (char *)FUN_0042a940(piVar8,(int)puVar18);
          if (iVar7 == 0x34) {
            FUN_0042ae10(PTR_DAT_0049cf30,3,pcVar9,0xffffffff,0);
          }
          else if (iVar7 == 0x36) {
            FUN_0042ae10(PTR_DAT_0049cf30,0,pcVar9,0xffffffff,0);
          }
          break;
        case 0x1a:
          FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          iVar7 = (local_5f8 & 0xff) * 0x1e0;
          if (*(int *)(&DAT_004e1d3c + iVar7) != 0) {
            iVar5 = FUN_00434f40(&DAT_004e1b80 + iVar7,(int)(short)local_5f0);
            FUN_004455a0(*(void **)(*(int *)(&DAT_004e1d3c + iVar7) + 0x538),0x107,iVar5,0);
          }
          break;
        case 0x1b:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042fc40(param_1,(undefined1 *)&local_558);
          iVar7 = (local_558 & 0xff) * 0x1e0;
          FUN_004354d0(&DAT_004e1b80 + iVar7,(local_5f8 & 0xff) >> 1,local_5f8 & 1);
          if (*(int *)(&DAT_004e1d3c + iVar7) != 0) {
            FUN_004455a0(*(void **)(*(int *)(&DAT_004e1d3c + iVar7) + 0x538),0x105,
                         (local_5f8 & 0xff) >> 1,local_5f8 & 1);
          }
          break;
        case 0x1e:
          FUN_0042fc40(param_1,(undefined1 *)&local_598);
          FUN_0042fc40(param_1,(undefined1 *)&local_59c);
          FUN_0042fc40(param_1,(undefined1 *)&local_4d8);
          puVar16 = &DAT_004e1b80 + (local_4d8 & 0xff) * 0x1e0;
          if ((char)local_598 == -1) {
            FUN_00435650(puVar16,local_59c & 0xff,0xffffffff);
          }
          else {
            FUN_00435650(puVar16,local_59c & 0xff,local_598 & 0xff);
            puVar3 = (undefined4 *)FUN_00433040(&DAT_004c7048,local_598 & 0xff);
            *puVar3 = puVar16;
          }
          break;
        case 0x1f:
          FUN_0042fc40(param_1,&local_5b5);
          FUN_0042fc40(param_1,(undefined1 *)&local_4d0);
          FUN_0042fc40(param_1,(undefined1 *)&local_528);
          uVar6 = local_528 & 0xff;
          if ((&DAT_004e1b80 + uVar6 * 0x1e0 == &DAT_004e1b80 + DAT_004e2a84 * 0x1e0) &&
             ((&DAT_004e1bbc)[uVar6 * 0x78] == 6)) {
            FUN_0043a120(0x4e1b78);
          }
          FUN_00435650(&DAT_004e1b80 + uVar6 * 0x1e0,local_4d0 & 0xff,0xffffffff);
          break;
        case 0x21:
          FUN_0042fc40(param_1,(undefined1 *)&local_51c);
          FUN_0042fc40(param_1,&local_5eb);
          puVar3 = (undefined4 *)FUN_00433040(&DAT_004c7048,local_51c & 0xff);
          if ((local_5eb & 1) != 0) {
            FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
            puVar3[0xe] = local_5f4;
          }
          if ((local_5eb & 2) != 0) {
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            puVar3[0xc] = local_5f8 & 0xff;
          }
          if ((local_5eb & 4) != 0) {
            FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
            puVar3[0xd] = local_5f4;
          }
          if ((local_5eb & 8) != 0) {
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            FUN_00431ea0(puVar3,local_5f8 & 0xff,*puVar3);
          }
          break;
        case 0x22:
          FUN_0042fc40(param_1,&local_5bd);
          FUN_0042fc40(param_1,(undefined1 *)&local_5b4);
          uVar6 = local_5b4;
          bVar1 = (byte)local_5b4;
          local_5b4 = local_5b4 & 0xffffff0f;
          local_55c = CONCAT31(local_55c._1_3_,bVar1 >> 4);
          iVar7 = FUN_00433060(&DAT_004c7048,uVar6 & 0xf,0);
          uVar6 = local_55c & 0xff;
          iVar7 = FUN_00433040(&DAT_004c7048,iVar7);
          *(uint *)(iVar7 + 0x30) = uVar6;
          break;
        case 0x23:
          FUN_0042fc40(param_1,(undefined1 *)&local_590);
          puVar3 = (undefined4 *)FUN_00433040(&DAT_004c7048,local_590 & 0xff);
          local_554 = (float)puVar3[0x15];
          local_54c = puVar3[0x17];
          local_550 = (float)puVar3[0x16] + 400.0;
          local_58c = 0.0;
          local_588 = 0;
          local_584 = 0;
          if ((void *)*puVar3 == (void *)0x0) {
            local_58c = (float)puVar3[0x15];
            local_588 = puVar3[0x16];
            local_584 = puVar3[0x17];
          }
          else {
            FUN_00436a70((void *)*puVar3,&local_58c);
          }
          FUN_004149e0(&local_58c,&local_554,puVar3[1],puVar3[0x11]);
          FUN_004330b0(&DAT_004c7048,local_590 & 0xff);
          break;
        case 0x24:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
          pvVar4 = (void *)FUN_00433040(&DAT_004c7048,local_5f8 & 0xff);
          uVar6 = (uint)(short)local_5f0;
          if ((int)(uVar6 & 0xffffff00) < 0xff00) {
            FUN_004323a0(pvVar4,uVar6 & 0xff,(int)uVar6 >> 8);
          }
          else {
            FUN_004323a0(pvVar4,uVar6 & 0xff,0x7fffffff);
          }
          break;
        case 0x25:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          iVar7 = FUN_00433040(&DAT_004c7048,local_5f8 & 0xff);
          *(undefined4 *)(iVar7 + 0x48) = 0;
          *(undefined4 *)(iVar7 + 0x44) = 1;
          *(undefined4 *)(iVar7 + 0x4c) = 0x40180000;
          break;
        case 0x32:
          FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
          FUN_0041aa80(&DAT_004e1b30,1,local_5f4);
          FUN_0045a2a0(DAT_00500178,-1,0);
          break;
        case 0x33:
          FUN_0042fc40(param_1,(undefined1 *)&local_4f4);
          FUN_0042fc40(param_1,&local_5e0);
          (&DAT_004e37c0)[local_4f4 & 0xff] = local_5e0;
          break;
        case 0x34:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
          FUN_0045a2a0(DAT_00500178,local_5f8 & 0xff,local_5f4);
          break;
        case 100:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
          uVar6 = local_5f4;
          pvVar4 = (void *)FUN_00441000(&DAT_004e37e0,local_5f8 & 0xff);
          FUN_004400b0(pvVar4,uVar6);
          break;
        case 0x65:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
          uVar6 = local_5f4;
          pvVar4 = (void *)FUN_00441000(&DAT_004e37e0,local_5f8 & 0xff);
          FUN_004400a0(pvVar4,uVar6);
          break;
        case 0x66:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          iVar7 = FUN_00441000(&DAT_004e37e0,local_5f8 & 0x7f);
          uVar6 = (local_5f8 & 0xff) >> 7;
          *(uint *)(iVar7 + 0x40) = uVar6;
          if (uVar6 != 0) {
            FUN_0042fbb0(param_1,(undefined1 *)(iVar7 + 0x4c));
            FUN_0042fbb0(param_1,(undefined1 *)(iVar7 + 0x50));
            FUN_0042fbb0(param_1,(undefined1 *)(iVar7 + 0xb8));
            FUN_0042fbb0(param_1,(undefined1 *)(iVar7 + 0xbc));
            FUN_0042fbb0(param_1,(undefined1 *)(iVar7 + 0xc0));
          }
          break;
        case 0x67:
          FUN_0042fc10(param_1,(undefined1 *)&local_4e4);
          FUN_0042fbb0(param_1,(undefined1 *)(local_544 + 3));
          FUN_0042fc40(param_1,(undefined1 *)&local_4f8);
          FUN_0042fc40(param_1,(undefined1 *)&local_500);
          uVar6 = local_4e4 & 0xffff;
          fVar14 = local_544[3];
          pvVar4 = (void *)FUN_00441000(&DAT_004e37e0,local_500 & 0xff);
          this_00 = (void *)FUN_00441000(&DAT_004e37e0,local_4f8 & 0xff);
          FUN_00440880(this_00,pvVar4,uVar6,fVar14);
          break;
        case 0x68:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          DAT_004e380c = local_5f8 & 0xff;
          break;
        case 0x69:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          pvVar4 = (void *)FUN_00441000(&DAT_004e37e0,local_5f8 & 0xff);
          FUN_00440b90(pvVar4);
          break;
        case 0x6a:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          iVar7 = 0;
          if ((char)local_5f8 != '\0') {
            do {
              FUN_0042fc40(param_1,(undefined1 *)&local_4f0);
              iVar5 = FUN_00441000(&DAT_004e37e0,local_4f0 & 0xff);
              FUN_0042fc10(param_1,(undefined1 *)&local_5ae);
              local_5e8 = (uint)local_5ae;
              iVar7 = iVar7 + 1;
              *(float *)(iVar5 + 0xac) =
                   ((float)(int)local_5e8 * 0.1 - *(float *)(iVar5 + 0x68)) /
                   *(float *)(iVar5 + 0x68);
              *(float *)(iVar5 + 0x68) = (float)(int)local_5e8 * 0.1;
            } while (iVar7 < (int)(local_5f8 & 0xff));
          }
          break;
        case 0x6d:
          *(uint *)((int)DAT_00508d24 + 0xc4) = *(uint *)((int)DAT_00508d24 + 0xc4) | 0x80;
          break;
        case 0x78:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0047efd0(&DAT_004d9078,local_5f8 & 0xff);
          FUN_00485290(acStack_141 + 1,&DAT_0049e078);
          uVar6 = 0xffffffff;
          pcVar9 = acStack_141;
          do {
            pcVar9 = pcVar9 + 1;
            if (uVar6 == 0) break;
            uVar6 = uVar6 - 1;
          } while (*pcVar9 != '\0');
          FUN_0042fc60(param_1,acStack_141 + ~uVar6);
          FUN_0042ae10(PTR_DAT_0049cf30,5,acStack_141 + 1,0xffffffff,0);
          break;
        case 0x79:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          uVar6 = local_5f8 & 0xff;
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          DAT_004d9454 = local_5f8 & 0xff;
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          DAT_004d9438 = local_5f8 & 0xff;
          puVar3 = &DAT_004d907c;
          do {
            *puVar3 = 0;
            puVar3 = puVar3 + 0x1e;
          } while ((int)puVar3 < 0x4d943c);
          iVar7 = 0;
          if (0 < (int)DAT_004d9438) {
            do {
              FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
              uVar12 = local_5f8 & 0xff;
              FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
              uVar13 = FUN_00424380((byte)local_5f8);
              (&DAT_004d9078)[uVar12 * 0x1e] = uVar13;
              FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
              uVar13 = FUN_00424380((byte)local_5f8);
              (&DAT_004d907c)[uVar12 * 0x1e] = uVar13;
              FUN_0042fc60(param_1,(char *)(uVar12 * 0x78 + 0x4d9090));
              iVar7 = iVar7 + 1;
            } while (iVar7 < (int)DAT_004d9438);
          }
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          _DAT_004d9440 = local_5f8 & 0xff;
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          DAT_004d9444 = (local_5f8 & 0xff) * 10000;
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          _DAT_004d9448 = local_5f8 & 0xff;
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          _DAT_004d944c = local_5f8 & 0xff;
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          DAT_004d9450 = local_5f8 & 0xff;
          if (uVar6 != 0) {
            iVar7 = FUN_00466570(4);
            *(undefined4 *)(iVar7 + 0xcf0) = 0;
            *(undefined4 *)(iVar7 + 0xcf4) = 0;
          }
          break;
        case 0x7a:
          iVar7 = FUN_00466570(7);
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          cVar2 = (char)local_5f8;
          if (cVar2 == -0x80) {
            *(undefined1 *)((int)DAT_00508d24 + 0x4170) = 0;
            FUN_0047c610((int)DAT_00508d24);
            *(undefined4 *)(iVar7 + 0x118) = 4;
            *(undefined4 *)(iVar7 + 0x11c) = 1;
          }
          else if (cVar2 == -0x7f) {
            *(undefined4 *)(iVar7 + 0x118) = 4;
            *(undefined4 *)(iVar7 + 0x11c) = 2;
          }
          else {
            if (cVar2 == -0x7e) {
              *(undefined4 *)(iVar7 + 0x118) = 4;
              *(undefined4 *)(iVar7 + 0x11c) = 3;
            }
            DAT_004d943c = local_5f8 & 0xff;
            if (*(int *)(iVar7 + 0x118) == 1) {
              *(undefined4 *)(iVar7 + 0x118) = 2;
            }
            else if (*(int *)(iVar7 + 0x118) == 3) {
              *(undefined4 *)(iVar7 + 0x118) = 4;
              *(undefined4 *)(iVar7 + 0x11c) = 0;
              break;
            }
            if (-1 < *(int *)((int)DAT_00508d24 + 0x2a0)) {
              FUN_0041a1e0(0);
              FUN_00423ec0(DAT_004fe7b0,0x3ee,(char *)0x0,0);
            }
          }
          break;
        case 0x7b:
          if (DAT_004fe7ac == 0) {
            *(undefined4 *)((int)local_4e0 + 0x8010) = 1;
          }
          break;
        case 0x7c:
          iVar7 = FUN_00466570(4);
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          if ((char)local_5f8 == -1) {
            *(undefined4 *)(iVar7 + 0xcfc) = 0xffffffff;
          }
          else {
            *(uint *)(iVar7 + 0xcfc) = local_5f8 & 0xff;
            FUN_0043e500(local_5f8 & 0xff);
          }
          break;
        case 200:
          iVar7 = FUN_0043a120(0x4e1b78);
          if (iVar7 != 0) {
            FUN_0042fc40(param_1,(undefined1 *)&local_334);
            iVar7 = 1;
            if (1 < (byte)local_334) {
              do {
                FUN_0042fc40(param_1,(undefined1 *)((int)&local_334 + iVar7));
                iVar7 = iVar7 + 1;
              } while (iVar7 < (int)(local_334 & 0xff));
            }
            FUN_0041dc20(&DAT_004c2358,(int)&local_334 + 1);
            FUN_00434280(&DAT_004e1b80 + DAT_004e2a84 * 0x1e0,100,
                         *(undefined4 *)((int)DAT_004fe7b0 + 0x8008));
          }
          break;
        case 0xc9:
          iVar7 = FUN_0043a120(0x4e1b78);
          if (iVar7 != 0) {
            FUN_0042fbb0(param_1,(undefined1 *)&local_4e8);
            DAT_004fdb3c = *(undefined4 *)
                            (*(int *)((&DAT_004e1b8c)[DAT_004e2a84 * 0x78] + 0x78) + 0x3c);
            puVar16 = &DAT_004fdb20;
            _DAT_004fdb34 = local_4e8;
            piVar8 = (int *)FUN_0042a8a0(&DAT_005090b0,0x5b);
            pcVar9 = (char *)FUN_0042a940(piVar8,(int)puVar16);
            FUN_00459fd0(DAT_00500178,pcVar9);
            FUN_00434280(&DAT_004e1b80 + DAT_004e2a84 * 0x1e0,0x65,
                         *(undefined4 *)((int)DAT_004fe7b0 + 0x8008));
          }
          break;
        case 0xcb:
          FUN_0042fc40(param_1,&local_3e0);
          FUN_0042fc80(param_1,(undefined4 *)&uStack_3df,
                       (CONCAT12(uStack_3de,CONCAT11(uStack_3df,local_3e0)) & 0xff) - 1);
          local_5d8 = FUN_0041ce10(&DAT_004c2358,
                                   CONCAT12(uStack_3dd,CONCAT11(uStack_3de,uStack_3df)) & 0xff,
                                   CONCAT12(uStack_3dc,CONCAT11(uStack_3dd,uStack_3de)) & 0xff,
                                   CONCAT12(local_3db,CONCAT11(uStack_3dc,uStack_3dd)) & 0xff);
          pvVar4 = (void *)(DAT_004c71ec +
                           (CONCAT12(bStack_3d8,CONCAT11(uStack_3d9,uStack_3da)) & 0xff) * 0x58);
          iVar7 = (CONCAT12(uStack_3d9,CONCAT11(uStack_3da,local_3db)) & 0xff) *
                  *(int *)((int)pvVar4 + 0x4c) +
                  (CONCAT12(uStack_3da,CONCAT11(local_3db,uStack_3dc)) & 0xff);
          uVar6 = (uint)CONCAT11(bStack_3d8,uStack_3d9);
          if ((uVar6 & 0x7f) == 0x3f) {
            iVar5 = 0;
          }
          else {
            iVar5 = FUN_00441000(&DAT_004e37e0,uVar6 & 0x7f);
            uVar6 = (uint)CONCAT11(bStack_3d8,uStack_3d9);
          }
          uVar6 = (uVar6 & 0xff) >> 7;
          local_5e8 = (uint)bStack_3d8;
          local_5e4 = (float)local_5e8 * 0.1;
          FUN_0041d310(pvVar4,iVar7,local_5d8,iVar5,uVar6,local_5e4);
          FUN_0041d9e0(pvVar4,1);
          FUN_0041d550(pvVar4,0,local_5e4);
          local_4cc[0] = 0.0;
          local_4cc[1] = 0.0;
          local_4cc[2] = 0.0;
          fVar14 = (float)*(int *)(local_5d8 + 0x34) * 0.5;
          local_5e8 = iVar7 % *(int *)((int)pvVar4 + 0x4c);
          FUN_0042b700(pvVar4,(float)(int)local_5e8 + fVar14,
                       (float)(iVar7 / *(int *)((int)pvVar4 + 0x4c)) + fVar14,local_4cc);
          if (uVar6 == 0) {
            FUN_00414b10(local_4cc,3.0);
          }
          break;
        case 0xcc:
          FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          pvVar4 = (void *)(DAT_004c71ec + (local_5f4 >> 0x10) * 0x58);
          local_5e8 = local_5f8 & 0xff;
          FUN_0041d470(pvVar4,local_5f4 & 0xffff,(float)local_5e8 * 0.1);
          FUN_0041d9e0(pvVar4,1);
          local_5e8 = local_5f8 & 0xff;
          FUN_0041d550(pvVar4,0,(float)local_5e8 * 0.1);
          break;
        case 0xcd:
          FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
          uVar6 = local_5f4 >> 8;
          uVar12 = local_5f4 >> 0x18;
          local_5e8 = local_5f4 >> 0x10 & 0xff;
          uVar13 = local_5f4 & 0xff;
          local_5f4 = uVar12;
          if (uVar12 < 0xff) {
            local_5cc = FUN_00441000(&DAT_004e37e0,uVar12);
          }
          else {
            local_5cc = 0;
          }
          pvVar4 = (void *)(DAT_004c71ec + (uVar6 & 0xff) * 0x58);
          local_5dc = (void *)((longlong)(ulonglong)uVar13 % (longlong)*(int *)((int)pvVar4 + 0x4c))
          ;
          local_5e4 = 0.0;
          local_548 = (int)((longlong)(ulonglong)uVar13 / (longlong)*(int *)((int)pvVar4 + 0x4c));
          if (0 < (int)local_5e8) {
            do {
              local_5a8 = (int)local_5e4 + local_548;
              local_5d8 = 0;
              do {
                iVar15 = local_5a8 * *(int *)((int)pvVar4 + 0x4c) + local_5d8 + (int)local_5dc;
                iVar5 = FUN_0042b1b0(pvVar4,iVar15);
                iVar7 = *(int *)(iVar5 + 0x34);
                *(int *)(iVar5 + 0x34) = local_5cc;
                if (((*(byte *)(iVar5 + 0xc) & 2) != 0) && (*(int *)(iVar5 + 0x30) == 0)) {
                  if (iVar7 != 0) {
                    FUN_00443010(&DAT_004c74c0,*(int **)(iVar5 + 0x10),0.0);
                    *(undefined4 *)(iVar5 + 0x10) = 0;
                  }
                  if (local_5cc != 0) {
                    FUN_0041d1a0(pvVar4,iVar15,1,*(int *)(iVar5 + 0x18),
                                 (uint)*(ushort *)(*(int *)(local_5cc + 0x2e0) + 0x1d8),0,2,0);
                  }
                }
                local_5d8 = local_5d8 + 1;
              } while (local_5d8 < (int)local_5e8);
              local_5e4 = (float)((int)local_5e4 + 1);
            } while ((int)local_5e4 < (int)local_5e8);
          }
          break;
        case 0xce:
          FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042ece0(*(void **)(DAT_004c71dc + 0x3c + (short)local_5f0 * 0x44),local_5f8 & 0xff);
          break;
        case 0xcf:
          iVar7 = *(int *)((int)DAT_00500178 + 0x54c);
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          *(uint *)(iVar7 + 0xe4) = local_5f8 & 0xff;
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          *(uint *)(iVar7 + 0xe8) = local_5f8 & 0xff;
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          *(int *)(iVar7 + 0xfc) = (int)(char)local_5f8;
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          *(uint *)(iVar7 + 0xec) = local_5f8 & 0xff;
          FUN_0042fbb0(param_1,(undefined1 *)(iVar7 + 0xf4));
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          *(uint *)(iVar7 + 0x104) = local_5f8 & 0xff;
          FUN_0045a6b0((int)DAT_00500178);
          break;
        case 0xd0:
          FUN_0042fc40(param_1,&local_5dd);
          if (local_5dd == '\0') {
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            if ((local_5f8 & 0x80) == 0) {
              uVar6 = local_5f8 & 0xff;
            }
            else {
              uVar6 = -(local_5f8 & 0x7f);
            }
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            if ((char)local_5f8 == -1) {
              iVar7 = 0;
            }
            else {
              iVar7 = FUN_00441000(&DAT_004e37e0,local_5f8 & 0xff);
            }
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            if ((char)local_5f8 == -1) {
              FUN_0042e770(&DAT_004c71c8,uVar6,iVar7,-1);
            }
            else {
              FUN_0042e770(&DAT_004c71c8,uVar6,iVar7,local_5f8 & 0xff);
            }
          }
          else if (local_5dd == '\x01') {
            FUN_0042fbb0(param_1,(undefined1 *)&local_5ac);
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            if ((char)local_5f8 == -1) {
              iVar7 = 0;
            }
            else {
              iVar7 = FUN_00441000(&DAT_004e37e0,local_5f8 & 0xff);
            }
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            if ((char)local_5f8 == -1) {
              uVar6 = 0xffffffff;
            }
            else {
              uVar6 = local_5f8 & 0xff;
            }
            FUN_0042e870(&DAT_004c71c8,local_5ac,iVar7,uVar6);
          }
          else if (local_5dd == '\x02') {
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            if ((local_5f8 & 0x80) == 0) {
              uVar6 = local_5f8 & 0xff;
            }
            else {
              uVar6 = -(local_5f8 & 0x7f);
            }
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            FUN_0042e990(uVar6,DAT_004c71e4 + (local_5f8 & 0xff) * 0x2c);
          }
          else {
            FUN_0042fbb0(param_1,(undefined1 *)&local_5ac);
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            FUN_0042e9e0(local_5ac,DAT_004c71e4 + (local_5f8 & 0xff) * 0x2c);
          }
        }
      }
    }
    else if (local_5d4 < 0x3f7) {
      if (local_5d4 == 0x3f6) {
        FUN_0042fc40(param_1,(undefined1 *)&local_4dc);
        FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
        FUN_00436710(&DAT_004e1b80 + (local_5f8 & 0xff) * 0x1e0,local_4dc & 0xff,
                     (uint)((local_5f8 & 0xff) != DAT_004e2a84));
      }
      else if (local_5d4 < 0x3eb) {
        if (local_5d4 == 0x3ea) {
          local_580[0] = 0.0;
          local_580[1] = 0.0;
          local_580[2] = 0.0;
          local_580[6] = 0.0;
          local_580[7] = 0.0;
          local_580[8] = 0.0;
          FUN_00427520(param_1,local_580);
          local_580[6] = local_580[0];
          local_580[8] = local_580[2];
          local_580[7] = *(float *)(*(int *)(*(int *)(DAT_0050d0d4 + 0xd8) + 0x10) + 0x160) + 100.0;
          FUN_00414890(local_580 + 6,local_580,0x40400000);
        }
        else if (local_5d4 < 0x1f9) {
          if (local_5d4 == 0x1f8) {
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            uVar6 = local_5f8 & 0xff;
            puVar16 = &DAT_004e1b80 + uVar6 * 0x1e0;
            FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
            uVar12 = (int)(short)local_5f0 & 0xff;
            iVar7 = (int)(short)local_5f0 >> 8;
            if (iVar7 == 0) {
              FUN_00434270(puVar16,0);
            }
            else {
              local_5dc = (void *)(&DAT_004e1bbc)[uVar6 * 0x78];
              if (puVar16 == &DAT_004e1b80 + DAT_004e2a84 * 0x1e0) {
                FUN_0043a120(0x4e1b78);
              }
              FUN_004342c0(puVar16,300,uVar12,iVar7);
              if (puVar16 == &DAT_004e1b80 + DAT_004e2a84 * 0x1e0) {
                FUN_00459fb0((int)DAT_00500178);
              }
              if (local_5dc != (void *)0x12c) {
                if (uVar12 == 1) {
                  FUN_00414ad0((&DAT_004e1b8c)[uVar6 * 0x78]);
                  FUN_00436cb0(puVar16,0,0x40080000);
                }
                else {
                  FUN_00436cb0(puVar16,0xa0000000,0x3fb99999);
                }
              }
            }
          }
          else {
            switch(local_5d4) {
            case 300:
              FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
              FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
              FUN_0042be80((void *)(DAT_004c71dc + (short)local_5f0 * 0x44),local_5f8 & 0xff);
              break;
            case 0x12d:
              FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
              FUN_0042bf30(DAT_004c71dc + (short)local_5f0 * 0x44);
              break;
            case 0x12e:
              FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
              FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
              FUN_00431cd0(&DAT_004c7100,(void *)(DAT_004c71dc + (short)local_5f0 * 0x44),
                           local_5f8 & 0xff);
              break;
            case 0x1f5:
              FUN_0042fc40(param_1,&local_514);
              FUN_0042fc40(param_1,local_513);
              break;
            case 0x1f7:
              FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
              uVar6 = local_5f8 & 0xff;
              FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
              pvVar4 = (void *)(DAT_004c71dc + (short)local_5f0 * 0x44);
              FUN_0042fbb0(param_1,(undefined1 *)&local_4d4);
              FUN_0042fc40(param_1,(undefined1 *)&local_50c);
              FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
              FUN_00423af0((void *)(&DAT_004e1b8c)[uVar6 * 0x78],pvVar4,local_4d4,local_5f8 & 1);
              FUN_00423290((void *)(&DAT_004e1b8c)[uVar6 * 0x78],local_50c & 0xff);
              *(uint *)((&DAT_004e1b8c)[uVar6 * 0x78] + 0x90) = (local_5f8 & 0xff) >> 1;
            }
          }
        }
        else if (local_5d4 < 0x227) {
          if (local_5d4 == 0x226) {
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
            FUN_0041aa80(&DAT_004e1b30,local_5f8 & 0xff,local_5f4);
          }
          else if (local_5d4 == 0x1f9) {
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            uVar6 = local_5f8 & 0xff;
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            *(uint *)((&DAT_004e1b8c)[uVar6 * 0x78] + 0x90) = local_5f8 & 0xff;
          }
          else if (local_5d4 == 0x1fa) {
            FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
            FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
            (&DAT_004e1cf8)[(local_5f8 & 0xff) * 0x78] = (int)(short)local_5f0;
          }
        }
        else if (local_5d4 == 1000) {
          FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
          FUN_0045a540(DAT_00500178,0.0,0.0,local_5f4 & 0xffffff);
          FUN_0043ee30(0x17);
        }
        else if (local_5d4 == 0x3e9) {
          local_4cc[9] = 0.0;
          local_4cc[10] = 0.0;
          local_4cc[0xb] = 0.0;
          FUN_00427520(param_1,local_4cc + 9);
          FUN_00414ee0(0x11,local_4cc + 9);
        }
      }
      else {
        switch(local_5d4) {
        case 0x3eb:
          local_4cc[0x1e] = 0.0;
          local_4cc[0x1f] = 0.0;
          local_4cc[0x20] = 0.0;
          FUN_00427520(param_1,local_4cc + 0x1e);
          FUN_00414ee0(6,local_4cc + 0x1e);
          break;
        case 0x3ec:
          FUN_0042fc10(param_1,(undefined1 *)&local_5a4);
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          local_544[0] = 0.0;
          local_544[1] = 0.0;
          local_544[2] = 0.0;
          FUN_0042bd30((void *)(DAT_004c71dc + local_5a4 * 0x44),0.0,0,local_544);
          FUN_00414ee0(1,local_544);
          FUN_00414910(local_544,10.0);
          break;
        case 0x3ee:
          FUN_0042fc10(param_1,(undefined1 *)&local_5b8);
          FUN_0042fc40(param_1,(undefined1 *)&local_4ec);
          local_4cc[0xf] = 0.0;
          local_4cc[0x10] = 0.0;
          local_4cc[0x11] = 0.0;
          FUN_0042bd30((void *)(DAT_004c71dc + local_5b8 * 0x44),0.0,0,local_4cc + 0xf);
          FUN_00414970(local_4cc + 0xf,local_4ec & 0xff);
          break;
        case 0x3ef:
          local_4cc[0x24] = 0.0;
          local_4cc[0x25] = 0.0;
          local_4cc[0x26] = 0.0;
          FUN_00427520(param_1,local_4cc + 0x24);
          FUN_00414ee0(0xd,local_4cc + 0x24);
          break;
        case 0x3f0:
          FUN_0042fc10(param_1,(undefined1 *)&local_5c6);
          FUN_0042fc40(param_1,(undefined1 *)&local_504);
          local_4cc[0x15] = 0.0;
          local_4cc[0x16] = 0.0;
          local_4cc[0x17] = 0.0;
          FUN_0042bd10((void *)(DAT_004c71dc + local_5c6 * 0x44),local_4cc + 0x15);
          FUN_00414a40(local_4cc + 0x15,local_504 & 0xff);
          break;
        case 0x3f1:
          FUN_0042fc10(param_1,(undefined1 *)&local_5a2);
          FUN_0042fc40(param_1,(undefined1 *)&local_5d0);
          uVar6 = local_5d0;
          uVar12 = local_5d0 & 0xff;
          local_5d0 = local_5d0 & 0xffffff7f;
          FUN_00414a80((int)local_5a2,uVar6 & 0x7f,uVar12 >> 7);
          break;
        case 0x3f2:
          FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
          local_4cc[0x2a] = 0.0;
          local_4cc[0x2b] = 0.0;
          local_4cc[0x2c] = 0.0;
          iVar7 = 3;
          pfVar17 = local_4cc + 0x2a;
          do {
            FUN_0042fc40(param_1,&local_5de);
            local_5dc = (void *)(int)local_5de;
            iVar7 = iVar7 + -1;
            *pfVar17 = (float)(int)local_5dc * 100.0;
            pfVar17 = pfVar17 + 1;
          } while (iVar7 != 0);
          FUN_0043ee80((int)(short)local_5f0,(int *)(local_4cc + 0x2a));
          break;
        case 0x3f3:
          FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
          uVar6 = local_5f4 & 0xff;
          local_5a8 = local_5f4 >> 8;
          local_5e4 = (float)(local_5a8 / 1000);
          if (local_5e4 == 0.0) {
            local_5e4 = 1.4013e-45;
          }
          else if (0x32 < (uint)local_5e4) {
            local_5e4 = 7.00649e-44;
          }
          local_534[0] = 0.0;
          local_534[1] = 0.0;
          local_534[2] = 0.0;
          local_4cc[0x1b] = 0.0;
          local_4cc[0x1c] = 0.0;
          local_4cc[0x1d] = 0.0;
          FUN_0042bd10(*(void **)((&DAT_004e1b8c)[uVar6 * 0x78] + 0x78),local_4cc + 0x1b);
          FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
          fVar14 = (float)((local_5f0 & 0xffff) >> 8);
          if ((local_5f0 & 0xff) == 0xff) {
            pfVar17 = local_534;
            pvVar4 = (void *)FUN_0042bb70(fVar14,1);
            FUN_0042bd10(pvVar4,pfVar17);
          }
          else {
            local_5dc = (void *)(DAT_004c71ec + (local_5f0 & 0xff) * 0x58);
            FUN_0042b670(local_5dc,fVar14,local_534,local_4cc + 0x2d);
            iVar7 = DAT_004e2a84 * 0x1e0;
            if ((&DAT_004e1d40)[DAT_004e2a84 * 0x78] != 0) {
              iVar5 = FUN_0042b1b0(local_5dc,(int)fVar14);
              iVar7 = FUN_00435620((int)(&DAT_004e1b80 + iVar7));
              if (*(int *)(iVar5 + 0x34) == iVar7) {
                FUN_00456bf0((int)DAT_00502ed0);
                FUN_00456780(DAT_00502ecc,0,0x40080000,local_5a8,
                             (int)(&DAT_004e1b80 + uVar6 * 0x1e0));
              }
            }
          }
          FUN_00414b50((int)local_5e4,local_4cc + 0x1b,local_534);
          break;
        case 0x3f4:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          iVar7 = 0;
          if ((char)local_5f8 != '\0') {
            do {
              FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
              iVar5 = DAT_004c71dc + (short)local_5f0 * 0x44;
              iVar15 = FUN_0042bb50(iVar5);
              iVar5 = FUN_0042b1b0(*(void **)(iVar5 + 0x28),*(int *)(iVar15 + 0x14));
              FUN_00443310(*(void **)(iVar5 + 0x10),4);
              iVar7 = iVar7 + 1;
            } while (iVar7 < (int)(local_5f8 & 0xff));
          }
          break;
        case 0x3f5:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_00414ad0((&DAT_004e1b8c)[(local_5f8 & 0xff) * 0x78]);
        }
      }
    }
    else if (local_5d4 < 0x7d1) {
      if (local_5d4 == 2000) {
        FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
        FUN_0041c320(&DAT_004c2348,local_5f4);
      }
      else {
        switch(local_5d4) {
        case 0x3f7:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042fc40(param_1,(undefined1 *)&local_520);
          FUN_00436840(&DAT_004e1b80 + (local_520 & 0xff) * 0x1e0,local_5f8 & 0x7f,
                       (local_5f8 & 0xff) >> 7,(uint)((local_520 & 0xff) != DAT_004e2a84));
          break;
        case 0x3f8:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0042fc40(param_1,(undefined1 *)&local_518);
          if ((local_518 & 0xff) == DAT_004e2a84) {
            local_358[0] = &DAT_004e1b80 + (local_518 & 0xff) * 0x1e0;
            piVar8 = (int *)FUN_0042a8a0(&DAT_005090b0,
                                         (local_5f8 & 0xf) +
                                         (((local_5f8 & 0xff) >> 4) + 0x3a) * 100);
            pcVar9 = (char *)FUN_0042a940(piVar8,(int)local_358);
            FUN_0042ae10(PTR_DAT_0049cf30,2,pcVar9,local_5f8 & 0xff,0);
          }
          break;
        case 0x3f9:
          local_4cc[0x27] = 0.0;
          local_4cc[0x28] = 0.0;
          local_4cc[0x29] = 0.0;
          FUN_00427520(param_1,local_4cc + 0x27);
          FUN_00414ee0(8,local_4cc + 0x27);
          break;
        case 0x3fa:
          local_4cc[0x21] = 0.0;
          local_4cc[0x22] = 0.0;
          local_4cc[0x23] = 0.0;
          FUN_00427580(param_1,local_4cc + 0x21);
          FUN_00414ee0(2,local_4cc + 0x21);
          break;
        case 0x3fb:
          local_4cc[0x18] = 0.0;
          local_4cc[0x19] = 0.0;
          local_4cc[0x1a] = 0.0;
          FUN_00427580(param_1,local_4cc + 0x18);
          FUN_00414ee0(1,local_4cc + 0x18);
          break;
        case 0x3fc:
          local_4cc[3] = 0.0;
          local_4cc[4] = 0.0;
          local_4cc[5] = 0.0;
          FUN_00427520(param_1,local_4cc + 3);
          FUN_00414ee0(5,local_4cc + 3);
          break;
        case 0x3fd:
          local_580[3] = 0.0;
          local_580[4] = 0.0;
          local_580[5] = 0.0;
          FUN_00427580(param_1,local_580 + 3);
          local_580[4] = local_580[4] + 100.0;
          FUN_00414ee0(10,local_580 + 3);
          break;
        case 0x3fe:
          local_4cc[6] = 0.0;
          local_4cc[7] = 0.0;
          local_4cc[8] = 0.0;
          FUN_00427580(param_1,local_4cc + 6);
          FUN_00414ee0(0xc,local_4cc + 6);
          break;
        case 0x3ff:
          local_4cc[0xc] = 0.0;
          local_4cc[0xd] = 0.0;
          local_4cc[0xe] = 0.0;
          FUN_00427520(param_1,local_4cc + 0xc);
          FUN_00414ee0(0xf,local_4cc + 0xc);
          break;
        case 0x400:
          local_4cc[0x12] = 0.0;
          local_4cc[0x13] = 0.0;
          local_4cc[0x14] = 0.0;
          FUN_00427580(param_1,local_4cc + 0x12);
          FUN_00414ee0(9,local_4cc + 0x12);
          break;
        case 0x401:
          FUN_00414b90(1.0,2.0);
          break;
        case 0x402:
          (**(code **)*DAT_00502ee0)(0,0x403e0000);
          break;
        case 0x403:
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          FUN_0040eba0(*(void **)(&DAT_004e1b8c)[(local_5f8 & 0xff) * 0x78],3,0,0x40140000);
          break;
        case 0x404:
          FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
          local_524 = CONCAT31(local_524._1_3_,(char)local_5f0);
          local_4fc = CONCAT31(local_4fc._1_3_,(char)(local_5f0 >> 8));
          FUN_00456880((int)DAT_00502ecc);
          FUN_00456b60(DAT_00502ed0,0,0x40100000,local_524 & 0xff,
                       (int)(&DAT_004e1b80 + (local_4fc & 0xff) * 0x1e0));
        }
      }
    }
    else if (local_5d4 < 0x9c5) {
      if (local_5d4 == 0x9c4) {
        FUN_0042fbb0(param_1,(undefined1 *)&local_5bc);
        pcVar9 = _malloc(local_5bc);
        FUN_0042fc80(param_1,(undefined4 *)pcVar9,local_5bc);
        FUN_0042fbb0(param_1,(undefined1 *)&local_5c4);
        pcVar10 = _malloc(local_5c4);
        FUN_0042fc80(param_1,(undefined4 *)pcVar10,local_5c4);
        FUN_00401000((byte *)s_build_new_server_0049e020);
        iVar7 = FUN_0043dbe0(&DAT_00508d28,pcVar9,local_5bc,pcVar10,local_5c4);
        if (iVar7 == 0) {
          FUN_0047c990((int)DAT_00508d24);
        }
        FUN_004851ae(pcVar9);
        FUN_004851ae(pcVar10);
      }
      else if (local_5d4 == 0x7d1) {
        FUN_0042fc10(param_1,(undefined1 *)&local_594);
        FUN_0042fc10(param_1,local_5ea);
        if ((local_5ea[0] & 1) != 0) {
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          local_410 = &DAT_004e1b80 + (local_5f8 & 0xff) * 0x1e0;
        }
        if ((local_5ea[0] & 2) != 0) {
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          local_40c = &DAT_004e1b80 + (local_5f8 & 0xff) * 0x1e0;
        }
        if ((local_5ea[0] & 4) != 0) {
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          local_408 = FUN_00441000(&DAT_004e37e0,local_5f8 & 0xff);
        }
        if ((local_5ea[0] & 8) != 0) {
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          local_404 = FUN_00441000(&DAT_004e37e0,local_5f8 & 0xff);
        }
        if ((local_5ea[0] & 0x10) != 0) {
          FUN_0042fbb0(param_1,local_400);
        }
        if ((local_5ea[0] & 0x20) != 0) {
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          local_3fc = FUN_0041f040(&DAT_004d9498,local_5f8 & 0xff);
        }
        if ((local_5ea[0] & 0x40) != 0) {
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          local_3f8 = DAT_004c71e4 + (local_5f8 & 0xff) * 0x2c;
        }
        if ((local_5ea[0] & 0x80) != 0) {
          FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
          local_3f4 = FUN_00433040(&DAT_004c7048,local_5f8 & 0xff);
        }
        piVar8 = (int *)FUN_0042a8a0(&DAT_005090b0,local_594 & 0xffff);
        pcVar9 = (char *)FUN_0042a940(piVar8,(int)local_414);
        uVar11 = (ushort)local_594;
        if (((uVar11 < 0xc81) || (0xca6 < uVar11)) && ((uVar11 < 0xce5 || (0xcec < uVar11)))) {
          FUN_0042ae10(PTR_DAT_0049cf30,piVar8[10],pcVar9,0xffffffff,local_594 & 0xffff);
        }
        else {
          FUN_0045a800(DAT_00500178,local_594 & 0xffff,pcVar9);
        }
      }
      else if (local_5d4 == 0x834) {
        FUN_0042fc10(param_1,(undefined1 *)&local_5f0);
        cVar2 = (char)local_5f0;
        local_508 = CONCAT31(local_508._1_3_,cVar2);
        local_510 = CONCAT31(local_510._1_3_,(char)(local_5f0 >> 8));
        FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
        uVar6 = local_510 & 0xff;
        if ((&DAT_004e1b80 + uVar6 * 0x1e0 == &DAT_004e1b80 + DAT_004e2a84 * 0x1e0) &&
           ((cVar2 == '\x02' || (cVar2 == '\x03')))) {
          FUN_0043a120(0x4e1b78);
        }
        FUN_00437970(&DAT_004e1b80 + uVar6 * 0x1e0,local_508 & 0xff,local_5f4);
      }
      else if (local_5d4 == 0x898) {
        (**(code **)*DAT_00502ec8)(0,0x403e0000);
        *(uint *)((int)DAT_00508d24 + 0xc4) = *(uint *)((int)DAT_00508d24 + 0xc4) | 0x200;
      }
    }
    else if (local_5d4 == 0x9c5) {
      FUN_0042fbb0(param_1,(undefined1 *)&local_5f4);
      FUN_00401000((byte *)s_connect_new_server_0049e00c);
      FUN_00427170(local_5f4);
    }
    else if (local_5d4 == 0x9c6) {
      FUN_0042fc40(param_1,(undefined1 *)&local_5f8);
      FUN_0047e900(DAT_00508d24,local_5f8 & 0xff);
    }
    if (local_5d4 == 0) {
      return;
    }
  } while( true );
}

