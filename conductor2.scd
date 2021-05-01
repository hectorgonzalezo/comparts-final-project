(
~bolero = BuffersFolder.read("Stems/Bolero".resolveRelative);
~mars = BuffersFolder.read("Stems/Mars".resolveRelative);
~lune = BuffersFolder.read("Stems/Lune".resolveRelative);
~kiev = BuffersFolder.read("Stems/Kiev".resolveRelative);

SynthDef(\vplay,
	{arg out = 0, buf, rate = 1, amp = 0.5, pos=0, gate=1, vol =1, vol2=1, mix=0.1, room = 0.2, lpfFreq = 10000, rq =1, freqForm=500, pan=0, delay= 0.2, decay= 1, delayMix=0;
		var sig, env;
		sig = PlayBuf.ar(2,buf,BufRateScale.ir(buf) * rate.lag2(0.3),1,BufDur.kr(buf)*pos*SampleRate.ir,doneAction:2);
		env = EnvGen.ar(Env.asr,gate,doneAction:2);
		sig = sig * env * amp.lag2(0.5);

		sig = RLPF.ar(sig, lpfFreq.lag2(0.3), rq);

		sig = XFade2.ar(sig, CombC.ar(sig, 1, delay.lag2(0.2), decay.lag2(0.2)), delayMix*2-1);

		sig = FreeVerb.ar(sig, mix, room);

		sig = Limiter.ar(sig, 0.8, 0.1);
		sig = Splay.ar(sig * vol.lag2(0.5) * vol2.lag2(0.5), 0, 1, pan);

		Out.ar(out,sig);
}).add;




//variables usedfor tiggers
~rhOldDepth = 0;
~rhOldX = 0;
~rhOldY = 0;

~lhOldDepth = 0;

///////////////////////////////////////////////////////////////////////
//autocalibration variables
////////////////////////////////////////////////////////////////////////
//upper limit of x
~rhXHi = 0;
//lower limit of x
~rhXLo = 0;

~rhYHi = 0;
~rhYLo = 0;
~rhZHi = 0.6;
~rhZLo = 1;



~lhXHi = 0;
~lhXLo = 0;
~lhYHi = 0;
~lhYLo = 0;
~lhZHi = 0.6;
~lhZLo = 1;



~headXHi = 0;
~headXLo = 0;
~headYHi = 0;
~headYLo = 0;
~headZHi = 0.6;
~headZLo = 1;



~bodyXHi = 0;
~bodyXLo = 0;
~bodyYHi = 0;
~bodyYLo = 0;
~bodyZHi = 0.6;
~bodyZLo = 1;

//groups for effects
~synthGrp = Group.new;



//function that places a piece
~player = {|piece, amp, out = 0| ~synths = {|buffer| Synth(\vplay, [\buf, piece[buffer], \out, out, \amp, amp], ~synthGrp)}!piece.size;};



//functions that grab OSC from certain addresses
OSCdef(
	\trackRH,
	{
		arg msg, time, addr, port;
		//msg.postln;


		~synthGrp.set(
			\vol, msg[2].linlin(~rhYLo, ~rhYHi, 0.05, 1),
			\rate, msg[3].linlin(~rhZLo, ~rhZHi, 2, -2).midiratio,
			\room, msg[1].lincurve(~rhXLo, ~rhXHi, 0.5, 1, 5),
			\mix, msg[1].lincurve(~rhXLo, ~rhXHi, 0.01, 1, 5)
		);



		~rhOldDepth = msg[3];


		~vol = msg[2].linlin(~rhYLo, ~rhYHi, 0.05, 1);
		//auto-calibration

		case
		{msg[1] > ~rhXHi} {~rhXHi = msg[1]}
		{msg[1] < ~rhXLo} {~rhXLo = msg[1]}
		{msg[2] > ~rhYHi} {~rhYHi = msg[2]}
		{msg[2] < ~rhYLo} {~rhYLo = msg[2]}
		{msg[3] > ~rhZHi} {~rhZHi = msg[3]}
		{msg[3] < ~rhZLo} {~rhZLo = msg[3]}


	},
	'/Hand_Right',
	nil,
	7000

);

/*OSCdef(
\trackLH,
{
arg msg, time, addr, port;
//msg.postln;



//auto-calibration

case
{msg[1] > ~lhXHi} {~lhXHi = msg[1]}
{msg[1] < ~lhXLo} {~lhXLo = msg[1]}
{msg[2] > ~lhYHi} {~lhYHi = msg[2]}
{msg[2] < ~lhYLo} {~lhYLo = msg[2]}
{msg[3] > ~lhZHi} {~lhZHi = msg[3]}
{msg[3] < ~lhZLo} {~lhZLo = msg[3]}


},
'/Hand_Left',
nil,
7000

);*/


OSCdef(
	\trackHead,
	{
		arg msg, time, addr, port;
		//msg.postln;

		~synthGrp.set(
			\lpfFreq, msg[2].linexp(~headYLo, ~headYHi, 2000, 10000),
			\rq, msg[3].linexp(~headZLo, ~headZHi, 2, 0.1)
		);

		//auto-calibration

		case
		{msg[1] > ~headXHi} {~headXHi = msg[1]}
		{msg[1] < ~headXLo} {~headXLo = msg[1]}
		{msg[2] > ~headYHi} {~headYHi = msg[2]}
		{msg[2] < ~headYLo} {~headYLo = msg[2]}
		{msg[3] > ~headZHi} {~headZHi = msg[3]}
		{msg[3] < ~headZLo} {~headZLo = msg[3]}


	},
	'/Head',
	nil,
	7000

);



OSCdef(
	\trackBody,
	{
		arg msg, time, addr, port;
		//msg.postln;



		~synthGrp.set(
			\pan, msg[1].linlin(~bodyXLo, ~bodyXHi, -0.75, 0.75),
			\delayMix, msg[3].linexp(~bodyZLo, ~bodyZHi, 0.001, 1),
			\decay, msg[3].linlin(~bodyZLo, ~bodyZHi, 0.5, 2),
			\delay, msg[2].linexp(~bodyYLo, ~bodyYHi, 0.3, 0.01)
		);


		//auto-calibration

		case
		{msg[1] > ~bodyXHi} {~bodyXHi = msg[1]}
		{msg[1] < ~bodyXLo} {~bodyXLo = msg[1]}
		{msg[2] > ~bodyYHi} {~bodyYHi = msg[2]}
		{msg[2] < ~bodyYLo} {~bodyYLo = msg[2]}
		{msg[3] > ~bodyZHi} {~bodyZHi = msg[3]}
		{msg[3] < ~bodyZLo} {~bodyZLo = msg[3]}


	},
	'/Body',
	nil,	7000

);



~triggers = {
	|i|
	OSCdef(
		\triggersVol++(i).asSymbol,
		{
			arg msg, time, addr, port;
			msg.postln;
			if(msg[1] == 1,
				{
					"trig".postln;
					{~synthGrp.set(\vol2, 0);
						0.1.wait;
					~synths[i].set(\vol2, 1);
					}.fork
				},
				{~synthGrp.set(\vol2, 1)}

			)
		},
		'/Trigger1_' ++ (i+1).asSymbol,
		nil,
		7000
	);
}!5;


)


(


//~player.value(~kiev, 0.8);
// ~player.value(~lune);
~player.value(~mars, 0.8);
//~player.value(~bolero);
)