#include <amxmodx>
#include <fakemeta>
#include <reapi>

#define XYZ 3

new Float:g_flOrigin[MAX_PLAYERS + 1][XYZ];
new Float:g_flPrevOrigin[MAX_PLAYERS + 1][XYZ];

new g_iPrevButtons[MAX_PLAYERS + 1];
new g_iOldButtons[MAX_PLAYERS + 1];

new bool:g_isLadder[MAX_PLAYERS + 1];
new bool:g_isPrevLadder[MAX_PLAYERS + 1];

new bool:g_isGround[MAX_PLAYERS + 1];
new bool:g_isPrevGround[MAX_PLAYERS + 1];

new bool:g_inDuck[MAX_PLAYERS + 1];
new bool:g_inPrevDuck[MAX_PLAYERS + 1];

new Float:g_flHorSpeed[MAX_PLAYERS + 1];
new Float:g_flPrevHorSpeed[MAX_PLAYERS + 1];

new Float:g_flMaxSpeed[MAX_PLAYERS + 1];

new bool:g_isSGS[MAX_PLAYERS + 1];

new Float:g_flMoveFirstZ[MAX_PLAYERS + 1];

enum MOVE_TYPE {
	MOVE_NOT = 0,
	MOVE_BHOP,
	MOVE_SGS,
	MOVE_DDRUN
}

new MOVE_TYPE:g_eSessionMoveType[MAX_PLAYERS + 1];

new bool:isSessionMove[MAX_PLAYERS + 1];

enum FOG_TYPE {
	FOG_PERFECT,
	FOG_GOOD,
	FOG_BAD
};

enum MOVE_ARTIFACTS {
	ARTIFACT_SMESTA,
	ARTIFACT_SURF,
	ARTIFACT_LADDER,
	ARTIFACT_DROP,
	ARTIFACT_UP
}

new MOVE_ARTIFACTS:g_eIARArtifact[MAX_PLAYERS + 1];

enum MOVE_STATS {
	STATS_COUNT,
	STATS_FOG[FOG_TYPE],
	Float:STATS_PRECENT,
	Float:STATS_AVG_SPEED,
	Float:STATS_MAX_SPEED,
	MOVE_ARTIFACTS:SATS_ARTIFACT,
}

new g_eMoveStats[MAX_PLAYERS + 1][MOVE_STATS];

new bool:g_bOneReset[MAX_PLAYERS + 1];

new g_bCmdMyShow[MAX_PLAYERS + 1];

public plugin_init() {
	register_plugin("HNS Move stats", "0.0.3", "OpenHNS");

	RegisterSayCmd("mystats", "movestats", "cmdMyShow", ADMIN_ALL, "Show my move stats");

	RegisterHookChain(RG_PM_Move, "rgPM_Move", true);

	RegisterHookChain(RG_CBasePlayer_Spawn, "rgPlayerSpawn");
}

public rgPM_Move(id) {
	if (is_user_bot(id) || is_user_hltv(id)) {
		return HC_CONTINUE;
	}

	static iFog[MAX_PLAYERS + 1];

	get_entvar(id, var_origin, g_flOrigin[id]);
	g_isLadder[id] = bool:(get_entvar(id, var_movetype) == MOVETYPE_FLY);
	g_isGround[id] = bool:(get_entvar(id, var_flags) & FL_ONGROUND);
	g_inDuck[id] = bool:(get_entvar(id, var_flags) & FL_DUCKING);
	g_iPrevButtons[id] = get_entvar(id, var_oldbuttons);
	g_flMaxSpeed[id] = get_maxspeed(id);

	new Float:flVelosity[3];
	get_entvar(id, var_velocity, flVelosity);
	g_flHorSpeed[id] = vector_hor_length(flVelosity);

	g_isGround[id] = g_isGround[id] || g_isLadder[id];

	g_isPrevGround[id] = g_isPrevGround[id] || g_isPrevLadder[id];

	if (g_isLadder[id]) {
		g_eIARArtifact[id] = ARTIFACT_LADDER;
	}

	if (g_isGround[id]) {
		if (iFog[id] <= 10) {
			iFog[id]++;
			g_bOneReset[id] = true;
		} else if (g_bOneReset[id]) {
			check_and_show_move(id);
			g_eIARArtifact[id] = ARTIFACT_SMESTA;
			g_bOneReset[id] = false;
		}

		if (iFog[id] == 1) {
			if (g_inDuck[id]) {
				g_isSGS[id] = true;
			} else {
				g_isSGS[id] = false;
			}
		}
	} else {
		if (isUserSurfing(id)) {
			g_eIARArtifact[id] = ARTIFACT_SURF;
		}
		
		if (g_isPrevGround[id]) {
			new bool:isDuck = !g_inDuck[id] && !(g_iPrevButtons[id] & IN_JUMP) && g_iOldButtons[id] & IN_DUCK;
			new bool:isJump = !isDuck && g_iPrevButtons[id] & IN_JUMP && !(g_iOldButtons[id] & IN_JUMP);

			if (isDuck) {
				if (iFog[id] > 10) {
					g_flMoveFirstZ[id] = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
				} else {
					if (!g_flMoveFirstZ[id]) {
						g_flMoveFirstZ[id] = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
					}
					
					if (g_eIARArtifact[id] == ARTIFACT_SMESTA) {
						new Float:flDuckZ = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
							
						if (flDuckZ - g_flMoveFirstZ[id] < -4.0) {
							g_eIARArtifact[id] = ARTIFACT_DROP;
						} else if (flDuckZ - g_flMoveFirstZ[id] > 4.0) {
							g_eIARArtifact[id] = ARTIFACT_UP;
						}
					}

					move_stats_counter(id, g_isSGS[id] ? MOVE_SGS : MOVE_DDRUN, iFog[id]);
				}
			}
			if (isJump) {
				if (iFog[id] > 10) {
					g_flMoveFirstZ[id] = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
				} else {
					if (!g_flMoveFirstZ[id]) {
						g_flMoveFirstZ[id] = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
					}

					if (g_eIARArtifact[id] == ARTIFACT_SMESTA) {
						new Float:flJumpZ = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];

						if (flJumpZ - g_flMoveFirstZ[id] < -4.0) {
							g_eIARArtifact[id] = ARTIFACT_DROP;
						} else if (flJumpZ - g_flMoveFirstZ[id] > 4.0) {
							g_eIARArtifact[id] = ARTIFACT_UP;
						}
					}

					move_stats_counter(id, MOVE_BHOP, iFog[id]);
				}
			}

			if (!isDuck && !isJump && flVelosity[2] <= -4.0) {
				if (iFog[id] > 10) {
					g_eIARArtifact[id] = ARTIFACT_DROP;
				}
			}
		}

		iFog[id] = 0;
	}

	g_iOldButtons[id] = g_iPrevButtons[id];

	g_flPrevOrigin[id] = g_flOrigin[id];

	g_isPrevGround[id] = g_isGround[id];
	g_isPrevLadder[id] = g_isLadder[id];
	g_inPrevDuck[id] = g_inDuck[id];

	g_flPrevHorSpeed[id] = g_flHorSpeed[id]

	return HC_CONTINUE;
}


public move_stats_counter(id, MOVE_TYPE:eMove, iFog) {
	if (g_eSessionMoveType[id] && (g_eSessionMoveType[id] != eMove)) {
		check_and_show_move(id);
	}

	g_eSessionMoveType[id] = eMove;

	if (g_eIARArtifact[id] == ARTIFACT_SURF) {
		if (eMove == MOVE_SGS || eMove == MOVE_DDRUN) {
			g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_SURF;
		}
	}

	if (g_eMoveStats[id][SATS_ARTIFACT] == ARTIFACT_SMESTA && g_eIARArtifact[id] != ARTIFACT_SMESTA) {
		g_eMoveStats[id][SATS_ARTIFACT] = g_eIARArtifact[id];
	}

	g_eMoveStats[id][STATS_COUNT]++;

	if (g_eMoveStats[id][STATS_COUNT] >= 5) {
		isSessionMove[id] = true;
	}

	switch(eMove) {
		case MOVE_BHOP: {
			if (g_flHorSpeed[id] < g_flMaxSpeed[id] && (iFog == 1 || iFog >= 2 && g_flPrevHorSpeed[id] > g_flMaxSpeed[id])) {
				g_eMoveStats[id][STATS_FOG][FOG_PERFECT]++;
			} else {
				switch(iFog) {
					case 1..2: g_eMoveStats[id][STATS_FOG][FOG_GOOD]++;
					default: g_eMoveStats[id][STATS_FOG][FOG_BAD]++;
				}
			}
		}
		case MOVE_SGS: {
			switch(iFog) {
				case 3: g_eMoveStats[id][STATS_FOG][FOG_PERFECT]++;
				case 4: g_eMoveStats[id][STATS_FOG][FOG_GOOD]++;
				default: g_eMoveStats[id][STATS_FOG][FOG_BAD]++;
			}
		}
		case MOVE_DDRUN: {
			switch(iFog) {
				case 2: g_eMoveStats[id][STATS_FOG][FOG_PERFECT]++;
				case 3: g_eMoveStats[id][STATS_FOG][FOG_GOOD]++;
				default: g_eMoveStats[id][STATS_FOG][FOG_BAD]++;
			}
		}
	}
	
	if (g_eMoveStats[id][STATS_MAX_SPEED] < g_flHorSpeed[id]) {
		g_eMoveStats[id][STATS_MAX_SPEED] = g_flHorSpeed[id];
	}

	g_eMoveStats[id][STATS_AVG_SPEED] += g_flHorSpeed[id];

	g_eMoveStats[id][STATS_PRECENT] = float(g_eMoveStats[id][STATS_FOG][FOG_PERFECT]) / float(g_eMoveStats[id][STATS_COUNT]) * 100.0;
}

public clear_move_stats(id) {
	arrayset(g_flOrigin[id], 0.0, XYZ);
	arrayset(g_flPrevOrigin[id], 0.0, XYZ);

	g_iPrevButtons[id] = 0;
	g_iOldButtons[id] = 0;

	g_isLadder[id] = false;
	g_isPrevLadder[id] = false;

	g_isGround[id] = false;
	g_isPrevGround[id] = false;

	g_inDuck[id] = false;
	g_inPrevDuck[id] = false;

	g_flHorSpeed[id] = 0.0;
	g_flPrevHorSpeed[id] = 0.0;

	g_flMaxSpeed[id] = 0.0;

	g_isSGS[id] = false;

	g_flMoveFirstZ[id] = 0.0;


	isSessionMove[id] = false;
	g_eSessionMoveType[id] = MOVE_NOT;
	g_eMoveStats[id][STATS_COUNT] = 0;

	g_eMoveStats[id][STATS_FOG][FOG_PERFECT] = 0;
	g_eMoveStats[id][STATS_FOG][FOG_GOOD] = 0;
	g_eMoveStats[id][STATS_FOG][FOG_BAD] = 0;

	g_eMoveStats[id][STATS_PRECENT] = 0.0;
	
	g_eMoveStats[id][STATS_AVG_SPEED] = 0.0;
	g_eMoveStats[id][STATS_MAX_SPEED] = 0.0;

	g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_SMESTA;
}

public client_connect(id) {
	g_bCmdMyShow[id] = true; // TODO: Save settings
	clear_move_stats(id);
}

public rgPlayerSpawn(id) {
	clear_move_stats(id);
}

/* FRONT */

public cmdMyShow(id) {
	g_bCmdMyShow[id] = !g_bCmdMyShow[id];

	if (g_bCmdMyShow[id]) {
		client_print_color(id, print_team_blue, "[^3MOVE^1] Показывать все свои сессии: ^3Включено^1.");
	} else {
		client_print_color(id, print_team_blue, "[^3MOVE^1] Показывать все свои сессии: ^3Выключено^1.");
	}
}

enum Visual {
	not_show = 0,
	good,
	holy, 
	pro, 
	god
};

new const g_szSounds[4][] = {
    "openhns/impressive.wav",
    "openhns/wickedsick.wav",
	"openhns/ne_very.wav",
	"openhns/vlastb.wav"
}

public plugin_precache() {
    for(new i; i < sizeof(g_szSounds); i++)
        precache_sound(g_szSounds[i]);
}

public check_and_show_move(id) {
	if (!isSessionMove[id]) {
		clear_move_stats(id);
		return;
	}
	
	g_eMoveStats[id][STATS_AVG_SPEED] = g_eMoveStats[id][STATS_AVG_SPEED] / float(g_eMoveStats[id][STATS_COUNT]);

	new Visual:eVisual = get_visual(id);

	sound_sessions(id, eVisual);
	show_sessions(id, eVisual);

	clear_move_stats(id);
}

public Visual:get_visual(id) {
	new Visual:eVisual = not_show;

	switch (g_eMoveStats[id][SATS_ARTIFACT]) {
		case ARTIFACT_SMESTA: {
			switch (g_eSessionMoveType[id]) {
				case MOVE_BHOP: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 290.0 && g_eMoveStats[id][STATS_PRECENT] >= 80.0) {
						eVisual = god
					} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 275.0 && g_eMoveStats[id][STATS_PRECENT] >= 70.0) {
						eVisual = pro
					} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 265.0 && g_eMoveStats[id][STATS_PRECENT] >= 60.0) {
						eVisual = holy
					} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
				case MOVE_SGS: {
					if (g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						if (g_eMoveStats[id][STATS_AVG_SPEED] >= 340.0) {
							eVisual = god
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 315.0) {
							eVisual = pro
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 270.0) {
							eVisual = holy
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0) {
							eVisual = good
						}
					} else {
						if (g_eMoveStats[id][STATS_AVG_SPEED] >= 315.0) {
							eVisual = pro
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 280.0) {
							eVisual = holy
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 265.0) {
							eVisual = good
						}
					}
				}
				case MOVE_DDRUN: {
					if (g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						if (g_eMoveStats[id][STATS_AVG_SPEED] >= 310.0) {
							eVisual = god
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 290.0) {
							eVisual = pro
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 270.0) {
							eVisual = holy
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0) {
							eVisual = good
						}
					} else {
						if (g_eMoveStats[id][STATS_AVG_SPEED] >= 300.0) {
							eVisual = pro
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 280.0) {
							eVisual = holy
						} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 265.0) {
							eVisual = good
						}
					}
				}
			}

		}
		case ARTIFACT_SURF, ARTIFACT_DROP, ARTIFACT_UP, ARTIFACT_LADDER: {
			switch (g_eSessionMoveType[id]) {
				case MOVE_BHOP: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
				case MOVE_SGS: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
				case MOVE_DDRUN: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
			}
		}
	}

	return eVisual
}


public sound_sessions(id, Visual:eVisual) {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new iPlayer = iPlayers[i];

		switch(eVisual) {
		case good: client_cmd(iPlayer, "spk %s", g_szSounds[0]);
		case holy: client_cmd(iPlayer, "spk %s", g_szSounds[1]);
		case pro: client_cmd(iPlayer, "spk %s", g_szSounds[2]);
		case god: client_cmd(iPlayer, "spk %s", g_szSounds[3]);
		}
	}
}


public show_sessions(id, Visual:eVisual) {
	new szArtifactMess[128];
	new iLenArtifact;

	switch (g_eMoveStats[id][SATS_ARTIFACT]) {
		case ARTIFACT_SURF: {
			iLenArtifact = format(szArtifactMess[iLenArtifact], sizeof szArtifactMess - iLenArtifact, "(on slide)");
		}
		case ARTIFACT_DROP: {
			iLenArtifact = format(szArtifactMess[iLenArtifact], sizeof szArtifactMess - iLenArtifact, "(drop)");
		}
		case ARTIFACT_UP: {
			iLenArtifact = format(szArtifactMess[iLenArtifact], sizeof szArtifactMess - iLenArtifact, "(upped)");
		}
		case ARTIFACT_LADDER: {
			iLenArtifact = format(szArtifactMess[iLenArtifact], sizeof szArtifactMess - iLenArtifact, "(ladder)");
		}
	}

	new szMoveMess[128];
	new iLenMove;

	switch (g_eSessionMoveType[id]) {
		case MOVE_BHOP: {
			iLenMove = format(szMoveMess[iLenMove], sizeof szMoveMess - iLenMove, "BHOP");
		}
		case MOVE_SGS: {
			iLenMove = format(szMoveMess[iLenMove], sizeof szMoveMess - iLenMove, "SGS");
		}
		case MOVE_DDRUN: {
			iLenMove = format(szMoveMess[iLenMove], sizeof szMoveMess - iLenMove, "DDRUN");
		}
	}

	switch(eVisual) {
		case good: client_print_color(0, print_team_grey, "^3%n^1 completed ^3%d^1 %s: ^3%.0f%%%^1 perfect, post avg. speed: ^3%.2f^1, max: ^3%.2f^1. ^3%s", id, g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], g_eMoveStats[id][STATS_MAX_SPEED], szArtifactMess);
		case holy: client_print_color(0, print_team_blue, "^3%n^1 completed ^3%d^1 %s: ^3%.0f%%%^1 perfect, post avg. speed: ^3%.2f^1, max: ^3%.2f^1. ^3%s", id, g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], g_eMoveStats[id][STATS_MAX_SPEED], szArtifactMess);
		case pro: client_print_color(0, print_team_red, "^3%n^1 completed ^3%d^1 %s: ^3%.0f%%%^1 perfect, post avg. speed: ^3%.2f^1, max: ^3%.2f^1. ^3%s", id, g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], g_eMoveStats[id][STATS_MAX_SPEED], szArtifactMess);
		case god: client_print_color(0, print_team_red, "^3%n^4 completed ^3%d^4 %s: ^3%.0f%%%^4 perfect, post avg. speed: ^3%.2f^4, max: ^3%.2f^4. ^3%s", id, g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], g_eMoveStats[id][STATS_MAX_SPEED], szArtifactMess);
		case not_show: {
			if (g_bCmdMyShow[id]) {
				client_print_color(id, print_team_blue, "You completed %d %s: %.0f%%% perfect, post avg. speed: %.2f, max: %.2f. %s", g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], g_eMoveStats[id][STATS_MAX_SPEED], szArtifactMess);
			}
		}
	}
}

/* FRONT */


/* UTILS */

stock Float:vector_hor_length(Float:flVel[3]) {
	new Float:flNorma = floatpower(flVel[0], 2.0) + floatpower(flVel[1], 2.0);
	if (flNorma > 0.0)
		return floatsqroot(flNorma);
		
	return 0.0;
}

stock Float:get_maxspeed(id) {
	new Float:flMaxSpeed;
	flMaxSpeed = get_entvar(id, var_maxspeed);
	
	return flMaxSpeed * 1.2;
}

stock bool:isUserSurfing(id) {
	new Float:origin[3], Float:dest[3];
	get_entvar(id, var_origin, origin);
	
	dest[0] = origin[0];
	dest[1] = origin[1];
	dest[2] = origin[2] - 1.0;

	new Float:flFraction;

	engfunc(EngFunc_TraceHull, origin, dest, 0, 
		g_inDuck[id] ? HULL_HEAD : HULL_HUMAN, id, 0);

	get_tr2(0, TR_flFraction, flFraction);

	if (flFraction >= 1.0) return false;
	
	get_tr2(0, TR_vecPlaneNormal, dest);

	return dest[2] <= 0.7;
}

stock RegisterSayCmd(const szCmd[], const szShort[], const szFunc[], flags = -1, szInfo[] = "") {
	new szTemp[65], szInfoLang[65];
	format(szInfoLang, 64, "%L", LANG_SERVER, szInfo);

	format(szTemp, 64, "say /%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say /%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	return 1;
}

/* UTILS */