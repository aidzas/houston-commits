module Houston
  module Commits
    module ProjectExt
      extend ActiveSupport::Concern

      included do
        has_many :commits, dependent: :destroy, extend: CommitSynchronizer
        has_many :deploys
        has_many :pull_requests, class_name: "Github::PullRequest"
        belongs_to :head, class_name: "Commit", foreign_key: "head_sha", primary_key: "sha"

        has_adapter :VersionControl
      end



      def environments
        @environments ||= deploys.environments.map(&:downcase).uniq
      end

      def environment(environment_name)
        Environment.new(self, environment_name)
      end



      def repo
        version_control
      end

      def version_control_temp_path
        Houston.root.join("tmp", "#{slug}.git").to_s # <-- the .git here is misleading; could be any kind of VCS
      end

      def find_commit_by_sha(sha)
        commits.find_or_create_by_sha(sha)
      end

      def read_file(path, options={})
        repo.read_file(path, options)
      end

      def on_github?
        repo.is_a? Houston::Adapters::VersionControl::GitAdapter::GithubRepo
      end



    end
  end
end
