FROM ubuntu:24.04

# Prevent interactive prompts during install
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    tmux \
    python3 \
    python3-pip \
    nodejs \
    npm \
    zsh \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Powerlevel10k theme
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/themes/powerlevel10k

# Install useful zsh plugins
RUN git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Set Powerlevel10k as the theme and enable plugins
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' /root/.zshrc \
    && sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' /root/.zshrc

# Copy in configs
COPY tmux.conf* /root/.tmux.conf
COPY .p10k.zsh* /root/.p10k.zsh

# Add p10k config sourcing to .zshrc if config exists
RUN echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> /root/.zshrc

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Set zsh as default shell
ENV SHELL=/bin/zsh

# Set up workspace
WORKDIR /workspace

# Default command: start tmux with zsh
CMD ["tmux", "new-session", "-s", "main"]
