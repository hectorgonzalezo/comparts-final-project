
(
x={
	var in, amp, freq, hasFreq, out;
	in = SoundIn.ar(0);
	amp = Amplitude.ar(in);
	# freq, hasFreq = Pitch.kr(in);
	LFTri.ar(freq*[1,2]) * amp;
}.play
)

x.free;




// Prepare the buffer
b = Buffer.alloc(s, 512);

(
x = {
	var sig, chain, onsets, pips, trigger;

	sig = SoundIn.ar(0);

	chain = FFT(b, sig);

	// - move the mouse left/right to change the threshold:
	onsets = Onsets.kr(chain, MouseX.kr(0,1), \complex);

	trigger= SendTrig.kr(onsets);

	pips = Gendy1.ar(mul: EnvGen.kr(Env.perc(0.001, 0.1, 0.2), onsets));

	Out.ar(0, ((sig * 0.1) + pips).dup);
}.play;
)

(
// register to receive message
a= OSCresponder(s.addr,'/tr',{ arg time,responder,msg;
	[time,responder,msg].postln;
}).add;
)

a.remove; //Free the OSCresponder
x.free; // Free the synth
b.free; // Free the buffer




(
s.freeAll;
s.reboot;
Window.closeAll;
s.waitForBoot{





	b = Buffer.alloc(s, s.sampleRate * 5, 1);

	~micBus = Bus.audio(s,1);
	~ptrBus = Bus.audio(s,1);


	//SynthDefs based on Eli Fieldsteel real time granulator:
	// https://github.com/elifieldsteel/SuperCollider-Tutorials/blob/master/full%20video%20scripts/26_script.scd

	SynthDef(\mic, {
		arg in=0, out=0, amp=1;
		var sig;
		sig = SoundIn.ar(in) * amp;
		Out.ar(out, sig);
	}).add;


	SynthDef(\ptr, {
		arg out=0, buf=0, rate =1;
		var sig;
		sig = Phasor.ar(0, BufRateScale.kr(buf)*rate, 0, BufFrames.kr(buf));
		Out.ar(out, sig);
	}).add;

	SynthDef(\rec, {
		arg ptrIn=0, micIn=0, buf=0;
		var ptr, sig;
		ptr = In.ar(ptrIn, 1);
		sig = In.ar(micIn, 1);
		BufWr.ar(sig, buf, ptr);
	}).add;




	SynthDef(\player, { |volIn= 0.2, fadeT =5, gateWhich=0, dens=20, baseDur=0.1, durRand=1, buf=0,
		rate=1, pos=0,
		grainEnv=(-1), sync= 1, pan=0, panRand=0, rateRand =1, gate=1, atk=1, rel=1, amp1=0.5, amp2=0.5, vol=1, out=0, ptrBus=0, ptrSampleDelay=20000, ptrRandSamples=5000, minPtrDelay=1000, fadeCurve = (-3)|

		var sig, env, densCtrl, rateCtrl, posCtrl, panCtrl, ptr, ptrRand, totalDelay, durCtrl, maxGrainDur, sig1, player, which;



		env = EnvGen.kr(Env.asr(atk,1,rel), gate, doneAction:2);

		densCtrl = Select.ar(sync, [Dust.ar(dens), Impulse.ar(dens)]); //para seleccionar si la densidad es fija o aleatoria

		durCtrl = baseDur * LFNoise1.ar(100).exprange(1/durRand, durRand);

		rateCtrl = rate * LFNoise1.ar(100).exprange(1/rateRand, rateRand);

		panCtrl = pan + LFNoise1.kr(100).bipolar(panRand);

		ptrRand = LFNoise1.ar(100).bipolar(ptrRandSamples);

		totalDelay = max(ptrSampleDelay - ptrRand, minPtrDelay);

		ptr = In.ar(ptrBus, 1);
		ptr = ptr - ptrSampleDelay;
		ptr = ptr / BufFrames.kr(buf);

		maxGrainDur = (totalDelay / rateCtrl) / SampleRate.ir;
		durCtrl = min(durCtrl , maxGrainDur);


		sig = GrainBuf.ar(
			2,
			densCtrl,
			durCtrl,
			buf,
			rateCtrl,
			ptr,
			2,
			panCtrl,
			grainEnv
		);

		sig1 = Splay.ar(SoundIn.ar(0)*volIn);


		which = EnvGen.kr(Env.asr(fadeT,0.9, fadeT, fadeCurve), gateWhich);

		player = XFade2.ar(sig1 * amp1, sig* amp2, which*2-1);

		Out.ar(out, player * env * vol)
	}).add;


	~micGrp = Group.new;
	~ptrGrp = Group.after(~micGrp);
	~recGrp = Group.after(~ptrGrp);
	~granGrp = Group.after(~recGrp);



	Synth(\mic, [\in, 0, \out, ~micBus], ~micGrp);
	Synth(\ptr, [\buf, b, \out, ~ptrBus],~ptrGrp);
	Synth(\rec, [\ptrIn, ~ptrBus, \micIn, ~micBus, \buf, b], ~recGrp);


	//Loads the forest sound buffer
	~forest = Buffer.read(s, PathName(thisProcess.nowExecutingPath).parentPath++"forest_long.wav");

	s.sync;
	b.zero;


	//plays 5 instances of the Synth, these are the main sounds
	~g = 5.collect({
		arg n;
		Synth(\player, [

			\amp2, 0.dbamp,
			\buf, b,
			\out, 0,
			\atk, 1,
			\rel, 2,
			\gate, 1,
			\sync, 1,
			\dens, exprand(20,60),
			\baseDur, 0.05,
			\durRand, 1.5,
			\rate, ((0..12)*(-1)).choose.midiratio,
			\rateRand, 1.midiratio,
			\pan, n.linlin(0, 4, -0.5, 0.5),
			\panRand, 0.5,
			\grainEnv, -1,
			\ptrBus, ~ptrBus,
			\ptrSampleDelay, n.linlin(0,4,20000,s.sampleRate*2),
			\ptrRandSamples, 10000,
			\minPtrDelay, 1000,

			\fadeT, rrand(1.0, 5.0),
			\fadeCurve, rrand(-2.0, -3.0)
		], ~granGrp
		);
	});
//0 no granulation, 1 granulation
	~granGrp.set(\gateWhich, 0);

	//variables for use of task below
	~lastSound = ~sound;
	~soundArray= Array.newClear;
	~soundAv = 0;
	~freeze = false;


		//Create GUI to inform about sound levels


	~gui = Window("Sound Level", Rect(400, 400, 500, 300));

	~currentSound = StaticText(~gui, Rect(100, 30, 400, 75))
	.string_("Current Sound : " ++~sound.asString)
	.stringColor_(Color.blue)
	.font_(Font("Candara", 30, true));


	~averageSound = StaticText(~gui, Rect(25, 150, 450,75))
	.string_("Average Sound :" ++~soundAv.asString)
	.stringColor_(Color.red)
	.font_(Font("Candara", 30, true));


	~gui.front;

	s.sync;





	//changes sound in real time according to data received by sensors
	Task({
		2.wait;
		inf.do{



			//freezes sound if sound is loud enough and movement is detected
			//also changes density and synchronous/asynchronous values in granulator
			if(((~sound >= (~soundAv)) && (~motion == 1) && (~freeze == false) && (0.004.coin)),
				{
					~ptrGrp.set(\rate, 1);
					~granGrp.set(\dens, {exprand(20,60)});
					[~granGrp.set(\sync, 1),~g.collect({|n| n.set(\sync, {[0, 1].choose})})].choose;
					"freeze".postln;
					~freeze = true;

					//sends output to GUI
					{~currentSound.string_("Current Sound : " ++~sound.asString).stringColor_(Color.green)}.defer;
h
			},
				{
					//sends output to GUI
					{~currentSound.string_("Current Sound : " ++~sound.asString).stringColor_(Color.blue)}.defer;
				}
			);


			//starts real time granulator if motion is detected
			~granGrp.set(\gateWhich, ~motion);

			//~motion.postln;

			//~sound.postln;

			//if no motion is detected and sound is frozen, unfreeze it
			if((~motion == 0) && (~freeze == true),
				{
					{~ptrGrp.set(\rate, 1);
						"unfreeze".postln;
					}.defer(1);
					~freeze = false;
			});


			//variable to compare previous sound volume
			~lastSound = ~sound;

			//variable that averages sound pressure values over time
			~soundArray = ~soundArray++~sound;
			~soundAv = ~soundArray.sum/~soundArray.size;

			//changes GUI values
			{~currentSound.string_("Current Sound : " ++~sound.asString)}.defer;
			{~averageSound.string_("Average Sound :" ++~soundAv.round(0.001).asString)}.defer;

			0.02.wait;
		}

	}
	).play;


}
)