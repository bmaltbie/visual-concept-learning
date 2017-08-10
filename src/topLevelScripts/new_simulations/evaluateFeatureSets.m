function evaluateFeatureSets(p,basetype,tr_data,te_data,semFile,genFile)
% evaluateFeatureSets(p,basetype,tr_data,te_data)

    % % % build all the stuff we need in advance % % %

    files_tr= tr_data.file;
    files_te= te_data.file;
    labels_tr = tr_data.label;
    labels_te = te_data.label;
    fprintf('training *and* testing image/label lists configured\n');

    files_tr_ge = cell(length(files_tr),1);
    files_tr_ca = cell(length(files_tr),1);
    parfor iFile = 1:length(files_tr)
        [d,f,~] = fileparts(files_tr{iFile});
        files_tr_ge{iFile} = [d '/' f '.' basetype '_gen_mat'];
        files_tr_ca{iFile} = [d '/' f '.' basetype '_cat_mat'];
    end
    fprintf('Built training general *and* conceptual feature cache lists\n');

    files_te_ge = cell(length(files_te),1);
    files_te_ca = cell(length(files_te),1);
    parfor iFile = 1:length(files_te)
        [d,f,~] = fileparts(files_te{iFile});
        files_te_ge{iFile} = [d '/' f '.' basetype '_gen_mat'];
        files_te_ca{iFile} = [d '/' f '.' basetype '_cat_mat'];
    end
    fprintf('Built testing general *and* conceptual feature cache lists\n');

    % % % create the functions that actually performs the evaluations % % %

    function multaryEvaluationHelper(outStem,m_tr,m_te,labels_tr,labels_te)

        assert(strcmp(p.method,'logreg'),'EvaluateFeatureSets: method should be logistic regression!\n');

        % create cross-validation splits for training with 1,2,4,8,... examples
        % (testing will always use the same images for comparison)
        splitFile = [p.outDir outStem '-splits.mat'];
        if ~exist(splitFile,'file')
            rngState = rng;
            cvsplit = multiclass_cv(labels_tr,p.nTrainingExamples,p.nRuns);
            save(splitFile,'-mat','rngState','cvsplit');
            fprintf('multiclass splits generated for %s\n',outStem);
        else
            load(splitFile,'-mat','cvsplit');
            fprintf('multiclass splits loaded for %s\n',outStem);
        end

        outFile = [p.outDir outStem '-evaluation.csv'];
        if ~exist(outFile,'file')
            options2 = p.options;
            options2.dir = [options2.dir outStem];
            results = evaluatePerformanceAlt(...
              m_tr',labels_tr',m_te',labels_te',cvsplit,options2);
            writetable(results,outFile);
        end
        fprintf('%s evaluated\n',outStem);

    end


    function binaryEvaluationHelper(outStem,tr,te,type,scores)
        % create cross-validation splits for training with 1,2,4,8,... examples
        % (testing will always use the same images for comparison)
        if (nargin < 5) scores = tr; end;
        if (nargin < 4), type = 'random'; end;
        fprintf('entered binary helper, %f\n', posixtime(datetime));
        %% splitFile = [p.outDir 'binary-splits.mat'];
        %% if ~exist(splitFile,'file')
        %%     fprintf('cannot find split file, %f\n', posixtime(datetime));
        %%     rngState = rng;
        %%     cvsplit = weird_cv(tr.y,p.nBinaryTrainingExamples,p.nRuns);
        %%     classes = randperm(size(tr.y,1), p.nBinaryCategories);
        %%     save(splitFile,'-mat','-v7.3','rngState','cvsplit','classes');
        %%     fprintf('binary splits generated for %s, %f\n',outStem, posixtime(datetime));
        %% else
        %%     fprintf('found split file, %f\n', posixtime(datetime));
        %%     load(splitFile,'-mat','cvsplit','classes');
        %%     fprintf('binary splits and classes loaded for %s, %f\n',outStem, posixtime(datetime));
        %% end

        classFile = [p.outDir 'binary-classes.mat'];
        if ~exist(classFile,'file')
            fprintf('cannot find class file, %f\n', posixtime(datetime));
            rngState = rng;
            classes = randperm(size(tr.y,2), p.nBinaryCategories);
            save(classFile,'-mat','-v7.3','rngState','classes');
            fprintf('classes generated for %s, %f\n',outStem, posixtime(datetime));
        else
            fprintf('found class file, %f\n', posixtime(datetime));
            load(classFile,'-mat','classes');
        end

        outFile = [p.outDir outStem '-evaluation.csv'];
        if ~exist(outFile,'file')
            fprintf('preparing for %s evaluation, %f\n', outStem, posixtime(datetime));
            options2 = p.options;
            options2.dir = [options2.dir outStem];
            results = evaluatePerformance(tr,te,options2, ...
              p.nBinaryTrainingExamples,p.nRuns,inf,type,scores,classes);
            writetable(results,outFile);
        end
        fprintf('%s evaluated, %f\n',outStem, posixtime(datetime));
    end

    % % % we'll do the following binary comparisons % % %
    %% - all features
    %% - high mean-activation (thresholded)
    %% - randomly chosen features (thresholded by providing random scores)
    %% - high semantic similarity (based on Wu-Palmer score)
    %% - high visual similarity (only for categorical features)

    % % % evaluate the general features % % %

    tr_ge = buildActivationMatrix(files_tr_ge,labels_tr, [p.outDir 'general-training-activations.mat']);
    te_ge = buildActivationMatrix(files_te_ge,labels_te, [p.outDir 'general-testing-activations.mat']);
    fprintf('Built generic activations\n');

    % multaryEvaluationHelper([basetype '-general-multary'],m_tr_ge,m_te_ge,labels_tr_ge,labels_te_ge);
    fprintf('calling general binary evaluation, %f\n', posixtime(datetime));
    binaryEvaluationHelper([basetype '-general-binary'],tr_ge,te_ge);
%   for iThresh = 1:length(p.testingThreshes)
%       thresh = num2str(p.testingThreshes(iThresh));
%       binaryEvaluationHelper([basetype '-general-binary-high-mean-' thresh],m_tr_ge,m_te_ge,labels_tr_ge,labels_te_ge,inf,thresh);
%       binaryEvaluationHelper([basetype '-general-binary-high-semantics-' thresh],m_tr_ca,m_te_ca,labels_tr_ge,labels_te_ge,inf,thresh,semantic_similarity);
%       rand_similarity = m_tr_ge(:,randperm(size(m_tr_ge,2)));
%       binaryEvaluationHelper([basetype '-general-binary-random-' thresh],m_tr_ca,m_te_ca,labels_tr_ge,labels_te_ge,thresh,rand_similarity);
%   end
%   clear m_tr_ge m_te_ge labels_tr_ge labels_te_ge;

%   % % % evaluate the categorical features % % %

%   [m_tr_ca,labels_tr_ca] = buildActivationMatrix(files_tr_ca,labels_tr);
%   [m_te_ca,labels_te_ca] = buildActivationMatrix(files_te_ca,labels_te);
%   fprintf('Built categorical activations\n');

%   multaryEvaluationHelper([basetype '-categorical-multary'],m_tr_ca,m_te_ca,labels_tr_ca,labels_te_ca);
%   binaryEvaluationHelper([basetype '-categorical-binary'],m_tr_ca,m_te_ca,labels_tr_ca,labels_te_ca);
%   for iThresh = 1:length(p.testingThreshes)
%       thresh = num2str(p.testingThreshes(iThresh));
%       binaryEvaluationHelper([basetype '-categorical-binary-high-mean-' thresh],m_tr_ca,m_te_ca,labels_tr_ca,labels_te_ca,thresh);
%       binaryEvaluationHelper([basetype '-categorical-binary-high-semantics-' thresh],m_tr_ca,m_te_ca,labels_tr_ca,labels_te_ca,thresh,semantic_similarity);
%       % TODO: still need to run these, which means getting the visual similarities!
%       % binaryEvaluationHelper([basetype '-categorical-binary-high-generic-' thresh],m_tr_ca,m_te_ca,labels_tr_ca,labels_te_ca,thresh,general_similarity);
%       rand_similarity = m_tr_ca(:,randperm(size(m_tr_ca,2)));
%       binaryEvaluationHelper([basetype '-categorical-binary-random-' thresh],m_tr_ca,m_te_ca,thresh,rand_similarity);
%   end
%   clear m_tr_ca m_te_ca labels_tr_ca labels_te_ca;

%   % % % evaluate the combination of general and categorical features % % %
% % [m_tr_ge,labels_tr_ge] = buildActivationMatrix(files_tr_ge,labels_tr);
% % [m_te_ge,labels_te_ge] = buildActivationMatrix(files_te_ge,labels_te);
% % fprintf('Built generic activations\n');
% % [m_tr_ca,~] = buildActivationMatrix(files_tr_ca,labels_tr);
% % [m_te_ca,~] = buildActivationMatrix(files_te_ca,labels_te);
% % fprintf('Built categorical activations\n');
% % multaryEvaluationHelper([basetype '-super'],[m_tr_ge;m_tr_ca],[m_te_ge;m_te_ca],labels_tr_ge,labels_te_ge);
% % binaryEvaluationHelper([basetype '-super'],[m_tr_ge;m_tr_ca],[m_te_ge;m_te_ca]);
end
