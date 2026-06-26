import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useApp } from '../../context/AppContext.jsx';
import NameStep from './steps/NameStep.jsx';
import SignUpStep from './steps/SignUpStep.jsx';
import DemographicsStep from './steps/DemographicsStep.jsx';
import GoalsStep from './steps/GoalsStep.jsx';
import StopBangStep from './steps/StopBangStep.jsx';
import LifestyleStep from './steps/LifestyleStep.jsx';
import SummaryStep from './steps/SummaryStep.jsx';
import CompletionStep from './steps/CompletionStep.jsx';
import './OnboardingFlow.css';

const STEPS = [
  NameStep, SignUpStep, DemographicsStep, GoalsStep,
  StopBangStep, LifestyleStep, SummaryStep, CompletionStep
];

export default function OnboardingFlow() {
  const { onboardingStep, setOnboardingStep } = useApp();
  const StepComponent = STEPS[onboardingStep];
  const total = STEPS.length - 1; // exclude completion

  const next = () => setOnboardingStep(s => Math.min(s + 1, STEPS.length - 1));
  const back = () => setOnboardingStep(s => Math.max(s - 1, 0));

  return (
    <div className="onboarding-root">
      <div className="onboarding-orb ob-orb-1" />
      <div className="onboarding-orb ob-orb-2" />

      <div className="onboarding-shell">
        {onboardingStep < total && (
          <div className="onboarding-header">
            {onboardingStep > 0 && (
              <button className="ob-back-btn" onClick={back} id="ob-back">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <path d="M19 12H5M12 5l-7 7 7 7"/>
                </svg>
              </button>
            )}
            <div className="ob-progress" style={{ marginLeft: onboardingStep === 0 ? 'auto' : 0 }}>
              <div className="step-dots">
                {Array.from({ length: total }).map((_, i) => (
                  <div key={i} className={`step-dot ${i === onboardingStep ? 'active' : ''}`} />
                ))}
              </div>
              <p className="ob-step-label">{onboardingStep + 1} of {total}</p>
            </div>
          </div>
        )}

        <AnimatePresence mode="wait">
          <motion.div
            key={onboardingStep}
            initial={{ opacity: 0, x: 40 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -40 }}
            transition={{ duration: 0.3, ease: 'easeInOut' }}
            className="onboarding-step"
          >
            <StepComponent onNext={next} onBack={back} />
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}
